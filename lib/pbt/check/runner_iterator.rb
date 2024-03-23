# frozen_string_literal: true

require "pbt/reporter/run_execution"

module Pbt
  module Check
    class RunnerIterator
      # TODO: implement shrink
      attr_accessor :run_execution

      # @param source_values [Enumerator]
      # @param verbose [Boolean]
      def initialize(source_values, verbose)
        @run_execution = Reporter::RunExecution.new(verbose)
        @source_values = source_values
      end

      # @return [Enumerator]
      def source_values_enumerator
        @source_values
      end

      # @param c [Pbt::Check::Case]
      # @return [void]
      def handle_result(c)
        if c.exception
          # failed run
          @run_execution.record_failure(c)
        else
          # successful run
          @run_execution.record_success
        end
      end
    end
  end
end
