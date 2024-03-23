# frozen_string_literal: true

require "pbt/reporter/run_details"

module Pbt
  module Reporter
    class RunExecution
      # @param verbose [Boolean]
      def initialize(verbose)
        @verbose = verbose
        @failure = nil
        @failures = []
        @num_successes = 0
      end

      # @param c [Pbt::Check::Case]
      def record_failure(c)
        if @failure.nil?
          @value = c.val
          @failure = c.exception
        end
        @failures << c
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
            num_runs: @num_successes + @failures.size,
            num_shrinks: 0,
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
