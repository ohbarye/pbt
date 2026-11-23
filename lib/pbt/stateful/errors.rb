# frozen_string_literal: true

module Pbt
  class InvalidConfiguration < StandardError; end

  module Stateful
    # Raised when a stateful specification is invalid (missing sut/commands, invalid DSL options, etc.).
    class InvalidSpec < Pbt::InvalidConfiguration; end

    # Raised when the generator cannot produce a valid command sequence or step arguments within budget.
    class GenerationError < StandardError; end

    # Raised when a user model callback violates the pure-model contract (e.g. mutating frozen state).
    class ModelError < StandardError; end

    # Normalized failure identity used during shrinking to prevent slipping into an unrelated bug.
    FailureSignature = Data.define(:stage, :target, :exception_class)

    # Wraps a failure raised during SUT lifecycle, command execution, verification, or invariant checking.
    class StepFailure < StandardError
      attr_reader :step_index, :step, :stage, :target, :signature, :teardown_error

      # @param message [String]
      # @param step_index [Integer, nil] 0-based index of the failing step, or nil for sut/initial invariant/teardown
      # @param step [Step, nil]
      # @param stage [Symbol] :sut, :run, :verify, :invariant, or :teardown
      # @param target [Symbol, String, nil] command name or invariant name
      # @param exception_class [Class] original exception class
      # @param teardown_error [Exception, nil] secondary error raised during teardown cleanup
      def initialize(message, step_index:, step:, stage:, target:, exception_class:, teardown_error: nil)
        frozen_target = target.is_a?(String) ? target.dup.freeze : target
        @step_index = step_index
        @step = step
        @stage = stage
        @target = frozen_target
        @signature = FailureSignature.new(stage: stage, target: frozen_target, exception_class: exception_class)
        @teardown_error = teardown_error
        super(message)
      end

      # Attach a teardown error raised while this failure was already propagating.
      #
      # @param error [Exception]
      # @return [self]
      def attach_teardown_error(error)
        @teardown_error = error
        self
      end

      def message
        base = super
        return base unless @teardown_error

        "#{base}\n  (teardown error: #{@teardown_error.class}: #{@teardown_error.message})"
      end
    end
  end
end
