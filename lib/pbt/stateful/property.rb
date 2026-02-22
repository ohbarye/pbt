# frozen_string_literal: true

module Pbt
  module Stateful
    # Property-compatible wrapper for command-based stateful testing.
    # It provides `generate`, `shrink` and `run`, so existing runners can execute it.
    class Property
      Step = Struct.new(:command, :args, keyword_init: true) do
        def inspect
          "#<Pbt::Stateful::Step command=#{command_label} args=#{args.inspect}>"
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
        raise ArgumentError, "sut must be callable" unless sut.respond_to?(:call)
        raise ArgumentError, "max_steps must be non-negative" if max_steps.negative?

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
          commands = @model.commands(state).select { |cmd| cmd.applicable?(state) }
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
          (sequence.length - 1).downto(0) do |length|
            y << sequence.first(length)
          end
        end
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
            raise e.class, "stateful step #{index} (#{command_name(command)}): #{e.message}", e.backtrace
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
    end
  end
end
