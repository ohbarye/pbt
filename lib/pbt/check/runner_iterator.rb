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
        @initial_failure = nil
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
      # When a test is successful, it records the success and returns false.
      # When a test fails with an accepted failure, it records the failure, sets up the next shrink values,
      # and returns true. When a shrink candidate fails with an unrelated error according to `property#same_failure?`,
      # it is ignored and returns false so shrinking continues on the current level.
      #
      # @param c [Case]
      # @return [Boolean] whether the failure was accepted
      def handle_result(c)
        if c.exception
          if @initial_failure && @property.respond_to?(:same_failure?) && !@property.same_failure?(@initial_failure, c.exception)
            return false
          end

          # failed run
          @initial_failure ||= c.exception
          @run_execution.record_failure(c)
          @next_values =
            if @property.respond_to?(:shrink_case)
              @property.shrink_case(c)
            elsif c.sample
              c.sample.shrink
            else
              @property.shrink(c.val)
            end
          true
        else
          # successful run
          @run_execution.record_success(c)
          false
        end
      end
    end
  end
end
