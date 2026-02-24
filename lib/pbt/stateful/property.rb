# frozen_string_literal: true

module Pbt
  module Stateful
    # Property-compatible wrapper for command-based stateful testing.
    # It provides `generate`, `shrink` and `run`, so existing runners can execute it.
    class Property
      REQUIRED_COMMAND_METHODS = %i[
        name
        arguments
        applicable?
        next_state
        run!
        verify!
      ].freeze

      Step = Struct.new(:command, :args, keyword_init: true) do
        def inspect
          "#<Pbt::Stateful::Step command=#{command_label}, args=#{args.inspect}>"
        end

        private

        def command_label
          if command.respond_to?(:name)
            command.name.inspect
          else
            command.class.name || command.class.inspect
          end
        end
      end

      # @param model [Object]
      # @param sut [Proc]
      # @param max_steps [Integer]
      def initialize(model:, sut:, max_steps:)
        validate_model!(model)
        raise Pbt::InvalidConfiguration, "sut must be callable" unless sut.respond_to?(:call)
        raise Pbt::InvalidConfiguration, "max_steps must be an Integer" unless max_steps.is_a?(Integer)
        raise Pbt::InvalidConfiguration, "max_steps must be non-negative" if max_steps.negative?

        @model = model
        @sut_factory = sut
        @max_steps = max_steps
      end

      # Generate a sequence of commands valid for the current model state.
      #
      # @param rng [Random]
      # @return [Array<Step>]
      def generate(rng)
        length = rng.rand(0..@max_steps)
        state = @model.initial_state
        sequence = []

        length.times do
          commands = commands_for(state, context: "generate").select { |cmd| cmd.applicable?(state) }
          break if commands.empty?

          command = commands[rng.rand(commands.length)]
          args = command.arguments.generate(rng)
          sequence << Step.new(command:, args:)
          state = command.next_state(state, args)
        end

        sequence
      end

      # Shrink a sequence by trying shorter prefixes first.
      #
      # @param sequence [Array<Hash, Step>]
      # @return [Enumerator<Array<Hash, Step>>]
      def shrink(sequence)
        Enumerator.new do |y|
          seen = {}

          (sequence.length - 1).downto(0) do |length|
            yield_shrink_candidate(y, seen, sequence.first(length))
          end

          sequence.each_with_index do |step, index|
            command, args = unpack_step(step)
            validate_command_protocol!(command, context: "shrink step #{index}")

            command.arguments.shrink(args).each do |shrunk_args|
              candidate = replace_step(sequence, index, command:, args: shrunk_args)
              next unless valid_sequence?(candidate)

              yield_shrink_candidate(y, seen, candidate)
            end
          end
        end
      end

      # Stateful properties currently require sequential execution because the model,
      # commands and SUT factory are ordinary Ruby objects and are not guaranteed to be
      # Ractor-shareable.
      #
      # @param _sequence [Array<Hash, Step>]
      # @raise [Pbt::InvalidConfiguration]
      def run_in_ractor(_sequence)
        raise Pbt::InvalidConfiguration, "Pbt.stateful does not support worker: :ractor yet; use worker: :none"
      end

      # Run the command sequence against a fresh SUT and verify each step.
      #
      # @param sequence [Array<Hash, Step>]
      # @return [void]
      def run(sequence)
        state = @model.initial_state
        sut = @sut_factory.call

        sequence.each_with_index do |step, index|
          command, args = unpack_step(step)
          validate_command_protocol!(command, context: "run step #{index}")

          unless command.applicable?(state)
            raise "invalid stateful sequence at step #{index}: #{command_name(command)}"
          end

          before_state = state

          begin
            after_state = command.next_state(before_state, args)
            result = command.run!(sut, args)
            command.verify!(
              before_state:,
              after_state:,
              args:,
              result:,
              sut:
            )
          rescue Exception => e # standard:disable Lint/RescueException:
            raise e.class,
              "stateful step #{index} (#{command_name(command)}): #{e.message} [args=#{args.inspect}]",
              e.backtrace
          end

          state = after_state
        end
      end

      private

      # @param step [Hash, Step]
      # @return [Array<Object, Object>]
      def unpack_step(step)
        case step
        in Step(command:, args:)
          [command, args]
        in {command:, args:}
          [command, args]
        else
          raise ArgumentError, "invalid stateful step: #{step.inspect}"
        end
      end

      # @param command [Object]
      # @return [String]
      def command_name(command)
        command.respond_to?(:name) ? command.name.to_s : (command.class.name || command.class.inspect)
      end

      # @param model [Object]
      # @return [void]
      def validate_model!(model)
        missing_methods = %i[initial_state commands].reject { |method_name| model.respond_to?(method_name) }
        return if missing_methods.empty?

        raise Pbt::InvalidConfiguration,
          "Pbt.stateful model must respond to #{missing_methods.join(", ")}"
      end

      # @param state [Object]
      # @param context [String]
      # @return [Array<Object>]
      def commands_for(state, context:)
        commands = @model.commands(state)

        unless commands.is_a?(Array)
          raise Pbt::InvalidConfiguration,
            "Pbt.stateful model.commands(state) must return Array, got #{commands.class} (context=#{context})"
        end

        commands.each { |command| validate_command_protocol!(command, context:) }
        commands
      end

      # @param command [Object]
      # @param context [String]
      # @return [void]
      def validate_command_protocol!(command, context:)
        missing_methods = REQUIRED_COMMAND_METHODS.reject { |method_name| command.respond_to?(method_name) }
        unless missing_methods.empty?
          raise Pbt::InvalidConfiguration,
            "Pbt.stateful command protocol mismatch for #{command.class} " \
            "(name=#{safe_command_label(command)}, missing: #{missing_methods.join(", ")}, context=#{context})"
        end

        validate_arguments_protocol!(command, context:)
      end

      # @param command [Object]
      # @param context [String]
      # @return [void]
      def validate_arguments_protocol!(command, context:)
        arguments = command.arguments
        missing_methods = %i[generate shrink].reject { |method_name| arguments.respond_to?(method_name) }
        return if missing_methods.empty?

        raise Pbt::InvalidConfiguration,
          "Pbt.stateful command arguments protocol mismatch for #{command.class} " \
          "(name=#{safe_command_label(command)}, missing: #{missing_methods.join(", ")}, context=#{context})"
      end

      # @param command [Object]
      # @return [String]
      def safe_command_label(command)
        command.respond_to?(:name) ? command.name.inspect : "<unknown>"
      end

      # @param sequence [Array<Hash, Step>]
      # @param index [Integer]
      # @param command [Object]
      # @param args [Object]
      # @return [Array<Hash, Step>]
      def replace_step(sequence, index, command:, args:)
        candidate = sequence.dup
        candidate[index] = rebuild_step(sequence[index], command:, args:)
        candidate
      end

      # @param step [Hash, Step]
      # @param command [Object]
      # @param args [Object]
      # @return [Hash, Step]
      def rebuild_step(step, command:, args:)
        case step
        in Step
          Step.new(command:, args:)
        in Hash
          {command:, args:}
        else
          raise ArgumentError, "invalid stateful step: #{step.inspect}"
        end
      end

      # @param sequence [Array<Hash, Step>]
      # @return [Boolean]
      def valid_sequence?(sequence)
        state = @model.initial_state

        sequence.each do |step|
          command, args = unpack_step(step)
          return false unless command.applicable?(state)

          state = command.next_state(state, args)
        end

        true
      rescue
        false
      end

      # @param y [Enumerator::Yielder]
      # @param seen [Hash{Array<Hash, Step> => true}]
      # @param candidate [Array<Hash, Step>]
      # @return [void]
      def yield_shrink_candidate(y, seen, candidate)
        return if seen[candidate]

        seen[candidate] = true
        y << candidate
      end
    end
  end
end
