# frozen_string_literal: true

require "pbt/stateful/errors"
require "pbt/stateful/types"
require "pbt/stateful/command"

module Pbt
  module Stateful
    Invariant = Data.define(:name, :block)

    # Immutable stateful model specification built by `SpecBuilder`.
    class Spec
      attr_reader :commands, :invariants

      def initialize(initial_state_kind:, initial_state_source:, lifecycle:, commands:, invariants:)
        @initial_state_kind = initial_state_kind
        @initial_state_source = initial_state_source
        @lifecycle = lifecycle
        @commands = commands.freeze
        @commands_by_name = commands.each_with_object({}) { |cmd, h| h[cmd.name] = cmd }.freeze
        @invariants = invariants.freeze
      end

      def arbitrary_initial_state?
        @initial_state_kind == :arbitrary
      end

      # Resolve initial state, returning `[frozen_value, sample_or_nil]`.
      #
      # @param rng [Random]
      # @return [Array(Object, Pbt::Arbitrary::Sample, nil)]
      def sample_initial_state(rng)
        case @initial_state_kind
        when :arbitrary
          sample = Pbt::Arbitrary::Sample.capture(@initial_state_source, rng)
          [Resolver.deep_freeze(Resolver.deep_dup(sample.value)), sample]
        when :block
          value =
            begin
              @initial_state_source.call
            rescue *Check::FATAL_EXCEPTIONS, Pbt::Arbitrary::EmptyDomainError, Pbt::Arbitrary::FilterExhaustedError
              raise
            rescue Exception => e # standard:disable Lint/RescueException
              err = ModelError.new("initial_state raised #{e.class}: #{e.message}")
              err.set_backtrace(e.backtrace) if e.backtrace
              raise err
            end
          [Resolver.deep_freeze(value), nil]
        else
          [Resolver.deep_freeze(Resolver.deep_dup(@initial_state_source)), nil]
        end
      end

      # @param name [Symbol]
      # @return [Command]
      def command_by_name(name)
        @commands_by_name.fetch(name)
      rescue KeyError
        raise InvalidSpec, "unknown stateful command: #{name.inspect}"
      end

      # Execute `body` with a freshly initialized SUT, guaranteeing teardown/around cleanup.
      #
      # @param initial_state [Object]
      # @yieldparam sut [Object]
      # @return [void]
      def with_sut(initial_state, &body)
        @lifecycle.call(initial_state, body)
      end
    end

    # Yield-builder for defining a stateful property specification.
    class SpecBuilder
      UNSET = Object.new.freeze
      private_constant :UNSET

      def initialize
        @initial_state_kind = :constant
        @initial_state_source = nil
        @initial_state_defined = false
        @sut_block = nil
        @teardown_block = nil
        @around_block = nil
        @commands = []
        @command_names = {}
        @invariants = []
      end

      def initial_state(value = UNSET, &block)
        raise InvalidSpec, "initial_state already defined" if @initial_state_defined

        if block && !value.equal?(UNSET)
          raise InvalidSpec, "initial_state accepts either a value/arbitrary or a block, not both"
        end

        if block
          @initial_state_kind = :block
          @initial_state_source = block
        elsif !value.equal?(UNSET)
          if Resolver.arbitrary?(value)
            @initial_state_kind = :arbitrary
            @initial_state_source = value
          else
            @initial_state_kind = :constant
            @initial_state_source = value
          end
        else
          raise InvalidSpec, "initial_state requires a value, an arbitrary, or a block"
        end

        @initial_state_defined = true
      end

      def sut(&block)
        raise InvalidSpec, "sut requires a block" unless block
        raise InvalidSpec, "sut already defined" if @sut_block
        raise InvalidSpec, "sut cannot be combined with around" if @around_block

        @sut_block = block
      end

      def teardown(&block)
        raise InvalidSpec, "teardown requires a block" unless block
        raise InvalidSpec, "teardown already defined" if @teardown_block
        raise InvalidSpec, "teardown cannot be combined with around" if @around_block

        @teardown_block = block
      end

      def around(&block)
        raise InvalidSpec, "around requires a block" unless block
        raise InvalidSpec, "around already defined" if @around_block
        raise InvalidSpec, "around cannot be combined with sut or teardown" if @sut_block || @teardown_block

        @around_block = block
      end

      def command(name, weight: 1)
        raise InvalidSpec, "command #{name.inspect} requires a block" unless block_given?

        builder = CommandBuilder.new(name: name, weight: weight)
        yield(builder)
        cmd = builder.build

        raise InvalidSpec, "duplicate command name: #{cmd.name.inspect}" if @command_names.key?(cmd.name)

        @command_names[cmd.name] = true
        @commands << cmd
      end

      def invariant(name = nil, &block)
        raise InvalidSpec, "invariant requires a block" unless block

        @invariants << Invariant.new(name: name, block: block)
      end

      def build
        raise InvalidSpec, "stateful spec must define at least one command" if @commands.empty?
        if @teardown_block && !@sut_block
          raise InvalidSpec, "teardown requires sut"
        end
        unless @sut_block || @around_block
          raise InvalidSpec, "stateful spec must define sut or around"
        end

        Spec.new(
          initial_state_kind: @initial_state_kind,
          initial_state_source: @initial_state_source,
          lifecycle: build_lifecycle,
          commands: @commands,
          invariants: @invariants
        )
      end

      private

      def build_lifecycle
        if @around_block
          build_around_lifecycle(@around_block)
        else
          build_sut_teardown_lifecycle(@sut_block, @teardown_block)
        end
      end

      def build_sut_teardown_lifecycle(sut_block, teardown_block)
        lambda do |initial_state, body|
          sut =
            begin
              Resolver.invoke_with_arity(sut_block, initial_state)
            rescue *Check::FATAL_EXCEPTIONS
              raise
            rescue Exception => e # standard:disable Lint/RescueException
              err = StepFailure.new(
                "sut setup failed: #{e.class}: #{e.message}",
                step_index: nil,
                step: nil,
                stage: :sut,
                target: nil,
                exception_class: e.class
              )
              err.set_backtrace(e.backtrace) if e.backtrace
              raise err
            end

          propagating_error = nil
          begin
            body.call(sut)
          rescue Exception => e # standard:disable Lint/RescueException
            propagating_error = e
            raise
          ensure
            if teardown_block
              begin
                Resolver.invoke_with_arity(teardown_block, sut)
              rescue *Check::FATAL_EXCEPTIONS
                raise
              rescue Exception => teardown_err # standard:disable Lint/RescueException
                if propagating_error.is_a?(StepFailure)
                  propagating_error.attach_teardown_error(teardown_err)
                elsif propagating_error.nil? || propagating_error.is_a?(PreconditionNotMet)
                  err = StepFailure.new(
                    "teardown failed: #{teardown_err.class}: #{teardown_err.message}",
                    step_index: nil,
                    step: nil,
                    stage: :teardown,
                    target: nil,
                    exception_class: teardown_err.class,
                    teardown_error: teardown_err
                  )
                  err.set_backtrace(teardown_err.backtrace) if teardown_err.backtrace
                  raise err
                end
              end
            end
          end
        end
      end

      def build_around_lifecycle(around_block)
        lambda do |initial_state, body|
          call_count = 0
          propagating_error = nil

          run = lambda do |sut|
            call_count += 1
            if call_count > 1
              raise InvalidSpec, "around must call run exactly once (called #{call_count} times)"
            end

            begin
              body.call(sut)
            rescue Exception => e # standard:disable Lint/RescueException
              propagating_error = e
              raise
            end
          end

          begin
            Resolver.invoke_with_arity(around_block, initial_state, run)
          rescue StepFailure, InvalidSpec, ModelError, PreconditionNotMet, *Check::FATAL_EXCEPTIONS
            raise
          rescue Exception => e # standard:disable Lint/RescueException
            if propagating_error.is_a?(StepFailure)
              propagating_error.attach_teardown_error(e)
              raise propagating_error
            elsif propagating_error && !propagating_error.is_a?(PreconditionNotMet)
              raise propagating_error
            end

            stage = (call_count == 0) ? :sut : :teardown
            err = StepFailure.new(
              "#{stage} failed: #{e.class}: #{e.message}",
              step_index: nil,
              step: nil,
              stage: stage,
              target: nil,
              exception_class: e.class,
              teardown_error: (stage == :teardown) ? e : nil
            )
            err.set_backtrace(e.backtrace) if e.backtrace
            raise err
          end

          if call_count != 1
            raise InvalidSpec, "around must call run exactly once (called #{call_count} times)"
          end

          raise propagating_error if propagating_error
        end
      end
    end
  end
end
