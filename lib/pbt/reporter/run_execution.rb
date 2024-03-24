# frozen_string_literal: true

require "pbt/reporter/run_details"

module Pbt
  module Reporter
    class RunExecution
      # @param verbose [Boolean]
      def initialize(verbose)
        @verbose = verbose
        @path_to_failure = []
        @failure = nil
        @failures = []
        @num_successes = 0
      end

      # @param c [Pbt::Check::Case]
      def record_failure(c, idx)
        @path_to_failure << idx
        @failures << c

        # value and failure can be updated through shrinking
        @value = c.val
        @failure = c.exception
      end

      def record_success
        @num_successes += 1
      end

      def success?
        !@failure
      end

      def to_run_details(params)
        if success?
          RunDetails.new(
            failed: false,
            num_runs: @num_successes,
            num_shrinks: 0,
            seed: params[:seed],
            counterexample: nil,
            error_message: nil,
            error_instance: nil,
            failures: @failures,
            verbose: @verbose,
            run_configuration: params
          )
        else
          RunDetails.new(
            failed: true,
            num_runs: @path_to_failure[0] + 1,
            num_shrinks: @path_to_failure.size - 1,
            seed: params[:seed],
            counterexample: @value,
            error_message: @failure.message,
            error_instance: @failure,
            failures: @failures,
            verbose: @verbose,
            run_configuration: params
          )
        end
      end
    end
  end
end
