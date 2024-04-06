# frozen_string_literal: true

require "delegate"
require "pbt/reporter/run_execution"

module Pbt
  module Check
    class RunnerIterator < DelegateClass(Array)
      attr_reader :run_execution

      # @param source_values [Enumerator]
      # @param property [Property]
      # @param verbose [Boolean]
      def initialize(source_values, property, verbose)
        @run_execution = Reporter::RunExecution.new(verbose)
        @property = property
        @next_values = source_values
        @current_index = -1
        enumerator = Enumerator.new do |y|
          loop do
            @current_index += 1
            y.yield @next_values.next
          end
        end
        super(enumerator) # delegate `#each` and etc. to enumerator
      end

      # @return [Boolean]
      def has_next?
        @next_values.peek
        true
      rescue StopIteration
        false
      end

      # @param c [Pbt::Check::Case]
      # @return [void]
      def handle_result(c)
        if c.exception
          # failed run
          @run_execution.record_failure(c, @current_index)
          @current_index = -1
          @next_values = @property.shrink(c.val)
        else
          # successful run
          @run_execution.record_success
        end
      end
    end
  end
end
