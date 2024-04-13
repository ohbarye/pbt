# frozen_string_literal: true

require "pbt/reporter/run_details"

module Pbt
  module Reporter
    # Represents the result of a single run of a property test.
    class RunExecution
      # @param verbose [Boolean] Whether to print verbose output.
      def initialize(verbose)
        @verbose = verbose
        @path_to_failure = []
        @failure = nil
        @failures = []
        @num_successes = 0
      end

      # Record a failure in the run.
      #
      # @param c [Pbt::Check::Case]
      def record_failure(c)
        @path_to_failure << c.index
        @failures << c

        # value and failure can be updated through shrinking
        @value = c.val
        @failure = c.exception
      end

      # Record a successful run.
      #
      # @return [void]
      def record_success
        @num_successes += 1
      end

      # Whether the test was successful.
      #
      # @return [Boolean]
      def success?
        !@failure
      end

      # Convert execution to run details.
      #
      # @param config [Hash] Configuration parameters used for the run.
      # @return [RunDetails] Details of the run.
      def to_run_details(config)
        if success?
          RunDetails.new(
            failed: false,
            num_runs: @num_successes,
            num_shrinks: 0,
            seed: config[:seed],
            counterexample: nil,
            counterexample_path: nil,
            error_message: nil,
            error_instance: nil,
            failures: @failures,
            verbose: @verbose,
            run_configuration: config
          )
        else
          RunDetails.new(
            failed: true,
            num_runs: @path_to_failure[0] + 1,
            num_shrinks: @path_to_failure.size - 1,
            seed: config[:seed],
            counterexample: @value,
            counterexample_path: @path_to_failure.join(":"),
            error_message: @failure.message,
            error_instance: @failure,
            failures: @failures,
            verbose: @verbose,
            run_configuration: config
          )
        end
      end
    end
  end
end
