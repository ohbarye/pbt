# frozen_string_literal: true

require "delegate"
require "pbt/reporter/run_execution"

module Pbt
  module Check
    # This class is an iterator of the generated/shrunken values.
    #
    # @private
    # @!attribute [r] run_execution [Reporter::RunExecution]
    class RunnerIterator < DelegateClass(Array)
      attr_reader :run_execution

      # @param source_values [Enumerator] Enumerator of generated values by arbitrary. This is used to determine initial N (=`num_runs`) cases.
      # @param property [Property] Property to test. This is used to shrink the failed case.
      # @param verbose [Boolean] Controls the verbosity of the output.
      def initialize(source_values, property, verbose)
        @run_execution = Reporter::RunExecution.new(verbose)
        @property = property
        @next_values = source_values
        enumerator = Enumerator.new do |y|
          loop do
            y.yield @next_values.next
          end
        end
        super(enumerator) # delegate `#each` and etc. to enumerator
      end

      # Check if there is a next value to test.
      # If there is no next value, it returns false. Otherwise true.
      #
      # @return [Boolean]
      def has_next?
        @next_values.peek
        true
      rescue StopIteration
        false
      end

      # Handle result of a test.
      # When a test is successful, it records the success.
      # When a test is failed, it records the failure and set up the next values to test with property#shrink.
      #
      # @param c [Case]
      # @return [void]
      def handle_result(c)
        if c.exception
          # failed run
          @run_execution.record_failure(c)
          @next_values = @property.shrink(c.val)
        else
          # successful run
          @run_execution.record_success
        end
      end
    end
  end
end
