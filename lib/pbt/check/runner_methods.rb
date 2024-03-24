# frozen_string_literal: true

require "pbt/check/runner_iterator"
require "pbt/check/tosser"
require "pbt/check/case"
require "pbt/reporter/run_details_reporter"

module Pbt
  module Check
    module RunnerMethods
      include Check::Tosser

      # @param name [String]
      # @param params [Hash]
      # @param property [Proc]
      def assert(name = "", params: {}, &property)
        out = check(property.call, params:)
        Reporter::RunDetailsReporter.new(name, out).report_run_details
      end

      private

      # @param property [Proc]
      # @param params [Hash]
      # @return [RunDetails]
      def check(property, params: {})
        config = Pbt.configuration.to_h.merge(params.to_h)
        initial_values = toss(property, config[:seed])
        source_values = Enumerator.new(config[:num_runs]) do |y|
          config[:num_runs].times do
            y.yield initial_values.next
          end
        end

        run_it(property, source_values, config).to_run_details(config)
      end

      # @param property [Proc]
      # @param source_values [Enumerator]
      # @param params [Hash]
      # @return [RunExecution]
      def run_it(property, source_values, params)
        runner = Check::RunnerIterator.new(source_values, property, params[:verbose])
        while runner.has_next?
          run_it_in_parallel(property, runner, params)
        end
        runner.run_execution
      end

      # @param property [Proc]
      # @param runner [RunnerIterator]
      # @param params [Hash]
      # @return [RunExecution]
      def run_it_in_parallel(property, runner, params)
        runner.map { |val|
          actor = property.run(val, params[:use_ractor])
          Case.new(val:, actor:, exception: nil)
        }.each do |c|
          c.actor.take
          runner.handle_result(c)
        rescue => e
          c.exception = e.cause
          runner.handle_result(c)
          break # Ignore the rest of the cases. Just pick up the first failure.
        end
      end
    end
  end
end
