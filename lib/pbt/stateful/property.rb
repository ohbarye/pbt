# frozen_string_literal: true

module Pbt
  module Stateful
    # Property-compatible wrapper for command-based stateful testing.
    # It provides `generate`, `shrink` and `run`, so existing runners can execute it.
    class Property
      ARG_AWARE_GENERATION_ATTEMPTS = 5

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
          candidates = generate_candidates_for(state, rng, context: "generate")
          break if candidates.empty?

          command, args = candidates[rng.rand(candidates.length)]
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
          state = @model.initial_state

          (sequence.length - 1).downto(0) do |length|
            yield_shrink_candidate(y, seen, sequence.first(length))
          end

          sequence.each_with_index do |step, index|
            command, args = unpack_step(step)
            validate_command_protocol!(command, state:, context: "shrink step #{index}")
            break unless applicable?(command, state, args, context: "shrink step #{index}")

            arbitrary_for(command, state, context: "shrink step #{index}").shrink(args).each do |shrunk_args|
              candidate = replace_step(sequence, index, command:, args: shrunk_args)
              next unless valid_sequence?(candidate)

              yield_shrink_candidate(y, seen, candidate)
            end

            state = command.next_state(state, args)
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
          validate_command_protocol!(command, state:, context: "run step #{index}")

          unless applicable?(command, state, args, context: "run step #{index}")
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

        commands.each { |command| validate_command_protocol!(command, state:, context:) }
        commands
      end

      # @param command [Object]
      # @param state [Object]
      # @param context [String]
      # @return [void]
      def validate_command_protocol!(command, state:, context:)
        missing_methods = REQUIRED_COMMAND_METHODS.reject { |method_name| command.respond_to?(method_name) }
        unless missing_methods.empty?
          raise Pbt::InvalidConfiguration,
            "Pbt.stateful command protocol mismatch for #{command.class} " \
            "(name=#{safe_command_label(command)}, missing: #{missing_methods.join(", ")}, context=#{context})"
        end

        validate_command_signature!(command, :arguments, valid_counts: [0, 1], expectation: "arguments or arguments(state)",
          context:)
        validate_command_signature!(command, :applicable?, valid_counts: [1, 2],
          expectation: "applicable?(state) or applicable?(state, args)", context:)
      end

      # @param command [Object]
      # @param arguments [Object]
      # @param context [String]
      # @return [void]
      def validate_arguments_protocol!(command, arguments, context:)
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

      # @param state [Object]
      # @param rng [Random]
      # @param context [String]
      # @return [Array<Array<Object, Object>>]
      def generate_candidates_for(state, rng, context:)
        commands_for(state, context:).filter_map do |command|
          args = generate_applicable_args(command, state, rng, context:)
          next if args.equal?(NoApplicableArgs)

          [command, args]
        end
      end

      # @param command [Object]
      # @param state [Object]
      # @param rng [Random]
      # @param context [String]
      # @return [Object]
      def generate_applicable_args(command, state, rng, context:)
        unless arg_aware_command?(command)
          return NoApplicableArgs unless applicable?(command, state, nil, context:)

          return arbitrary_for(command, state, context:).generate(rng)
        end

        arbitrary = arbitrary_for_generate(command, state, context:)
        return NoApplicableArgs if arbitrary.equal?(NoApplicableArgs)

        ARG_AWARE_GENERATION_ATTEMPTS.times do
          args = generate_args_for(command, arbitrary, rng)
          return NoApplicableArgs if args.equal?(NoApplicableArgs)

          return args if applicable?(command, state, args, context:)
        end

        NoApplicableArgs
      end

      # @param command [Object]
      # @param state [Object]
      # @param context [String]
      # @return [Object]
      def arguments_for(command, state, context:)
        method = command.method(:arguments)

        if supports_argument_count?(method, 1)
          command.arguments(state)
        elsif supports_argument_count?(method, 0)
          command.arguments
        else
          raise_invalid_signature!(command, :arguments, "arguments or arguments(state)", context)
        end
      end

      # @param command [Object]
      # @param state [Object]
      # @param context [String]
      # @return [Object]
      def arbitrary_for(command, state, context:)
        arguments = arguments_for(command, state, context:)
        validate_arguments_protocol!(command, arguments, context:)
        arguments
      end

      # @param command [Object]
      # @param state [Object]
      # @param context [String]
      # @return [Object]
      def arbitrary_for_generate(command, state, context:)
        arbitrary_for(command, state, context:)
      rescue StandardError => e
        raise if e.is_a?(Pbt::InvalidConfiguration)
        raise unless state_aware_arg_aware_command?(command)

        # For state-aware arg-aware commands, materialization failure means the
        # current state has no representable argument candidates, so skip it.
        NoApplicableArgs
      end

      # @param command [Object]
      # @param arbitrary [Object]
      # @param rng [Random]
      # @return [Object]
      def generate_args_for(command, arbitrary, rng)
        arbitrary.generate(rng)
      rescue StandardError => e
        raise if e.is_a?(Pbt::InvalidConfiguration)
        raise unless state_aware_arg_aware_command?(command)

        # Treat generation failure the same way as materialization failure above.
        NoApplicableArgs
      end

      # @param command [Object]
      # @param state [Object]
      # @param args [Object]
      # @param context [String]
      # @return [Boolean]
      def applicable?(command, state, args, context:)
        method = command.method(:applicable?)

        if supports_argument_count?(method, 2)
          command.applicable?(state, args)
        elsif supports_argument_count?(method, 1)
          command.applicable?(state)
        else
          raise_invalid_signature!(command, :applicable?, "applicable?(state) or applicable?(state, args)", context)
        end
      end

      # @param command [Object]
      # @return [Boolean]
      def arg_aware_command?(command)
        supports_argument_count?(command.method(:applicable?), 2)
      end

      # @param command [Object]
      # @return [Boolean]
      def state_aware_arg_aware_command?(command)
        arg_aware_command?(command) && supports_argument_count?(command.method(:arguments), 1)
      end

      # @param command [Object]
      # @param method_name [Symbol]
      # @param valid_counts [Array<Integer>]
      # @param expectation [String]
      # @param context [String]
      # @return [void]
      def validate_command_signature!(command, method_name, valid_counts:, expectation:, context:)
        method = command.method(method_name)
        return if valid_counts.any? { |count| supports_argument_count?(method, count) }

        raise_invalid_signature!(command, method_name, expectation, context)
      end

      # @param command [Object]
      # @param method_name [Symbol]
      # @param expectation [String]
      # @param context [String]
      # @return [void]
      def raise_invalid_signature!(command, method_name, expectation, context)
        raise Pbt::InvalidConfiguration,
          "Pbt.stateful command protocol mismatch for #{command.class} " \
          "(name=#{safe_command_label(command)}, invalid #{method_name} signature; expected #{expectation}, context=#{context})"
      end

      # @param method [Method]
      # @param count [Integer]
      # @return [Boolean]
      def supports_argument_count?(method, count)
        return false if method.parameters.any? { |kind, _name| keyword_parameter?(kind) }

        required = 0
        optional = 0
        rest = false

        method.parameters.each do |kind, _name|
          case kind
          when :req
            required += 1
          when :opt
            optional += 1
          when :rest
            rest = true
          end
        end

        return false if count < required
        return true if rest

        count <= required + optional
      end

      # @param kind [Symbol]
      # @return [Boolean]
      def keyword_parameter?(kind)
        %i[keyreq key keyrest].include?(kind)
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
          return false unless applicable?(command, state, args, context: "validate sequence")

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

      NoApplicableArgs = Object.new
      private_constant :NoApplicableArgs
    end
  end
end
