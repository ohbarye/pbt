# frozen_string_literal: true

require "pbt/reporter/run_details"

module Pbt
  module Reporter
    # Represents the result of a single run of a property test.
    class RunExecution
      attr_reader :num_successes, :num_skips

      # A tree node of the execution for verbose output.
      ExecutionTreeNode = Struct.new(
        :result,
        :value,
        :children
      )

      # @param verbose [Boolean] Whether to print verbose output.
      def initialize(verbose)
        @verbose = verbose
        @path_to_failure = []
        @failure = nil
        @too_many_skips_error = nil
        @failures = []
        @num_successes = 0
        @num_skips = 0
        @num_runs_on_failure = nil
        @root_execution_trees = []
        @current_level_execution_trees = @root_execution_trees
      end

      # Record a failure in the run.
      #
      # @param c [Pbt::Check::Case]
      def record_failure(c)
        @num_runs_on_failure ||= @num_successes + 1
        if @verbose
          current_tree = append_execution_tree_node(:failure, c.val)
          @current_level_execution_trees = current_tree.children
        end
        @path_to_failure << c.index
        @failures << c

        # value and failure can be updated through shrinking
        @value = c.val
        @failure = c.exception
      end

      # Record a successful run.
      #
      # @param c [Pbt::Check::Case]
      # @return [void]
      def record_success(c)
        if @verbose
          append_execution_tree_node(:success, c.val)
        end
        @num_successes += 1
      end

      # Record a skipped initial run (from `Pbt.assume`).
      #
      # @return [void]
      def record_skip
        @num_skips += 1
      end

      # Record a failure caused by exceeding `max_skips`.
      #
      # @param error [Pbt::TooManySkipsError]
      # @return [void]
      def record_too_many_skips(error)
        @too_many_skips_error = error
      end

      # @return [Boolean]
      def too_many_skips?
        !@too_many_skips_error.nil?
      end

      # Whether the test was successful.
      #
      # @return [Boolean]
      def success?
        !@failure && !@too_many_skips_error
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
            num_skips: @num_skips,
            num_shrinks: 0,
            seed: config[:seed],
            counterexample: nil,
            counterexample_path: nil,
            error_message: nil,
            error_instance: nil,
            failures: @failures,
            verbose: @verbose,
            execution_summary: @root_execution_trees,
            run_configuration: config
          )
        elsif @too_many_skips_error
          RunDetails.new(
            failed: true,
            num_runs: @num_successes,
            num_skips: @num_skips,
            num_shrinks: 0,
            seed: config[:seed],
            counterexample: nil,
            counterexample_path: nil,
            error_message: @too_many_skips_error.message,
            error_instance: @too_many_skips_error,
            failures: @failures,
            verbose: @verbose,
            execution_summary: @root_execution_trees,
            run_configuration: config
          )
        else
          RunDetails.new(
            failed: true,
            num_runs: @num_runs_on_failure,
            num_skips: @num_skips,
            num_shrinks: @path_to_failure.size - 1,
            seed: config[:seed],
            counterexample: @value,
            counterexample_path: @path_to_failure.join(":"),
            error_message: @failure.message,
            error_instance: @failure,
            failures: @failures,
            verbose: @verbose,
            execution_summary: @root_execution_trees,
            run_configuration: config
          )
        end
      end

      private

      # @param result [Symbol] The result of the current node.
      # @param value [Object] The value to test.
      # @return [Hash] The current execution tree.
      def append_execution_tree_node(result, value)
        current_tree = ExecutionTreeNode.new(result:, value:, children: [])
        @current_level_execution_trees << current_tree
        current_tree
      end
    end
  end
end
