# frozen_string_literal: true

require "pbt/stateful/errors"
require "pbt/stateful/types"

module Pbt
  module Stateful
    # Immutable command specification built by `CommandBuilder`.
    class Command
      attr_reader :name, :weight

      def initialize(name:, weight:, guard_block:, arguments_source:, precondition_block:, next_state_block:, run_block:, verify_block:)
        @name = name
        @weight = weight
        @guard_block = guard_block
        @arguments_source = arguments_source
        @precondition_block = precondition_block
        @next_state_block = next_state_block
        @run_block = run_block
        @verify_block = verify_block
      end

      # @param state [Object]
      # @return [Boolean]
      def guard?(state)
        return true unless @guard_block

        !!Resolver.invoke_with_arity(@guard_block, state)
      rescue *Check::FATAL_EXCEPTIONS
        raise
      rescue Exception => e # standard:disable Lint/RescueException
        raise_model_error("guard", e)
      end

      # @param state [Object]
      # @return [Object] arbitrary responding to generate/shrink (or sample)
      def arguments_for(state)
        arb =
          if @arguments_source.nil?
            Pbt.nil
          elsif @arguments_source.is_a?(Proc)
            Resolver.invoke_with_arity(@arguments_source, state)
          else
            @arguments_source
          end

        validate_arbitrary!(arb)
        arb
      rescue Pbt::Arbitrary::EmptyDomainError, InvalidSpec, *Check::FATAL_EXCEPTIONS
        raise
      rescue Exception => e # standard:disable Lint/RescueException
        raise_model_error("arguments", e)
      end

      # @param state [Object]
      # @param args [Object]
      # @return [Boolean]
      def precondition?(state, args)
        return true unless @precondition_block

        !!Resolver.invoke_with_arity(@precondition_block, state, args)
      rescue *Check::FATAL_EXCEPTIONS
        raise
      rescue Exception => e # standard:disable Lint/RescueException
        raise_model_error("precondition", e)
      end

      # @param state [Object]
      # @param args [Object]
      # @param ref [Ref]
      # @return [Object] deep-frozen next model state
      def next_state(state, args, ref)
        return state unless @next_state_block

        next_s = Resolver.invoke_with_arity(@next_state_block, state, args, ref)
        Resolver.deep_freeze(next_s)
      rescue FrozenError => e
        raise ModelError,
          "command #{name.inspect} next_state attempted to mutate frozen model state: #{e.message}. " \
          "Return a new state value instead (e.g. `state.with(...)`, `[*arr, x]`, `hash.merge(...)`)."
      rescue *Check::FATAL_EXCEPTIONS
        raise
      rescue Exception => e # standard:disable Lint/RescueException
        raise_model_error("next_state", e)
      end

      # @param sut [Object]
      # @param concrete_args [Object]
      # @return [Object]
      def run!(sut, concrete_args)
        Resolver.invoke_with_arity(@run_block, sut, concrete_args)
      end

      # @param context [Context]
      # @return [void]
      def verify!(context)
        return unless @verify_block

        Resolver.invoke_with_arity(@verify_block, context)
      end

      private

      def validate_arbitrary!(arb)
        return if arb.respond_to?(:sample) || (arb.respond_to?(:generate) && arb.respond_to?(:shrink))

        raise InvalidSpec,
          "command #{name.inspect} arguments must return an arbitrary responding to generate and shrink (or sample), got #{arb.class}"
      end

      def raise_model_error(callback_name, error)
        err = ModelError.new("command #{name.inspect} #{callback_name} raised #{error.class}: #{error.message}")
        err.set_backtrace(error.backtrace) if error.backtrace
        raise err
      end
    end

    # Yield-builder for defining a single stateful command.
    class CommandBuilder
      def initialize(name:, weight:)
        raise InvalidSpec, "command name must be a Symbol, got #{name.inspect}" unless name.is_a?(Symbol)
        unless weight.is_a?(Integer) && weight.positive?
          raise InvalidSpec, "command #{name.inspect} weight must be a positive Integer, got #{weight.inspect}"
        end

        @name = name
        @weight = weight
        @guard_block = nil
        @arguments_source = nil
        @arguments_defined = false
        @precondition_block = nil
        @next_state_block = nil
        @run_block = nil
        @verify_block = nil
      end

      def guard(&block)
        raise InvalidSpec, "command #{@name.inspect} guard requires a block" unless block
        raise InvalidSpec, "command #{@name.inspect} guard already defined" if @guard_block

        @guard_block = block
      end

      def arguments(*args, **kwargs, &block)
        raise InvalidSpec, "command #{@name.inspect} arguments already defined" if @arguments_defined

        @arguments_source =
          if block
            unless args.empty? && kwargs.empty?
              raise InvalidSpec, "command #{@name.inspect} arguments accepts either a value, keyword arbitraries, or a block"
            end
            block
          elsif !kwargs.empty?
            unless args.empty?
              raise InvalidSpec, "command #{@name.inspect} arguments cannot mix positional and keyword arguments"
            end
            Pbt.fixed_hash(kwargs)
          elsif args.size == 1
            arb = args.first
            if !arbitrary?(arb)
              raise InvalidSpec, "command #{@name.inspect} arguments must be an arbitrary, got #{arb.class}"
            end
            arb
          else
            raise InvalidSpec, "command #{@name.inspect} arguments expects a single arbitrary, keyword arbitraries, or a block"
          end

        @arguments_defined = true
      end

      def precondition(&block)
        raise InvalidSpec, "command #{@name.inspect} precondition requires a block" unless block
        raise InvalidSpec, "command #{@name.inspect} precondition already defined" if @precondition_block

        @precondition_block = block
      end

      def next_state(&block)
        raise InvalidSpec, "command #{@name.inspect} next_state requires a block" unless block
        raise InvalidSpec, "command #{@name.inspect} next_state already defined" if @next_state_block

        @next_state_block = block
      end

      def run(&block)
        raise InvalidSpec, "command #{@name.inspect} run requires a block" unless block
        raise InvalidSpec, "command #{@name.inspect} run already defined" if @run_block

        @run_block = block
      end

      def verify(&block)
        raise InvalidSpec, "command #{@name.inspect} verify requires a block" unless block
        raise InvalidSpec, "command #{@name.inspect} verify already defined" if @verify_block

        @verify_block = block
      end

      def build
        raise InvalidSpec, "command #{@name.inspect} must define run" unless @run_block

        Command.new(
          name: @name,
          weight: @weight,
          guard_block: @guard_block,
          arguments_source: @arguments_source,
          precondition_block: @precondition_block,
          next_state_block: @next_state_block,
          run_block: @run_block,
          verify_block: @verify_block
        )
      end

      private

      def arbitrary?(obj)
        obj.respond_to?(:sample) || (obj.respond_to?(:generate) && obj.respond_to?(:shrink))
      end
    end
  end
end
