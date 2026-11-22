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

      # @param source_values [Enumerator] Enumerator of generated values by arbitrary.
      # @param property [Property] Property to test. This is used to shrink the failed case.
      # @param verbose [Boolean] Controls the verbosity of the output.
      # @param target_runs [Integer, nil] Number of non-skipped runs to complete before stopping.
      # @param max_skips [Integer, nil] Maximum number of skipped initial runs allowed via `Pbt.assume`.
      def initialize(source_values, property, verbose, target_runs: nil, max_skips: nil)
        @run_execution = Reporter::RunExecution.new(verbose)
        @property = property
        @source_stream = source_values
        @target_runs = target_runs
        @max_skips = max_skips
        @initial_failure = nil
        @initial_offset = 0
        @next_values = @target_runs ? next_initial_batch(@target_runs) : source_values
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
        return false if @run_execution.too_many_skips?

        begin
          @next_values.peek
          true
        rescue StopIteration
          if @target_runs && @initial_failure.nil?
            remaining = @target_runs - @run_execution.num_successes
            if remaining.positive?
              @next_values = next_initial_batch(remaining)
              @next_values.peek
              return true
            end
          end
          false
        end
      end

      # Map a pass-local index to the stream index during initial runs, or keep local index during shrinking.
      #
      # @param local_index [Integer]
      # @return [Integer]
      def case_index(local_index)
        (@target_runs && @initial_failure.nil?) ? (@initial_offset + local_index) : local_index
      end

      # Handle a case discarded by `Pbt.assume`.
      # During shrinking, skipped candidates are ignored without counting toward `max_skips`.
      #
      # @return [Boolean] whether the skip budget was exceeded and execution should stop
      def handle_skip
        return false if @initial_failure

        @run_execution.record_skip
        if @max_skips && @run_execution.num_skips > @max_skips
          error = TooManySkipsError.new(
            "Too many skipped runs: #{@run_execution.num_skips} skip(s) while attempting #{@target_runs} run(s) (#{@run_execution.num_successes} passed)"
          )
          @run_execution.record_too_many_skips(error)
          return true
        end

        false
      end

      # Handle result of a test.
      # When a test is successful, it records the success and returns false.
      # When a test fails with an accepted failure, it records the failure, sets up the next shrink values,
      # and returns true. When a shrink candidate fails with an unrelated error according to `property#same_failure?`,
      # it is ignored and returns false so shrinking continues on the current level.
      # Properties implementing `shrink_case(c)` must return an `Enumerator` (since `#has_next?` calls `#peek`).
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

      private

      def next_initial_batch(count)
        @initial_offset = @run_execution.num_successes + @run_execution.num_skips
        Enumerator.new(count) do |y|
          count.times do
            y.yield @source_stream.next
          end
        end
      end
    end
  end
end
