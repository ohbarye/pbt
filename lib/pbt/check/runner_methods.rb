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
      # @return [RunExecution]
      def run_it(property, source_values, params)
        shrink = ->(val) { property.shrink(val) }
        # shrink.call(1)
        runner = Check::RunnerIterator.new(source_values, shrink, params[:verbose])

        cases = []
        runner.source_values_enumerator.each do |val|
          actor = property.run(val, params[:use_ractor])
          cases << Case.new(val:, actor:, exception: nil)
        end

        cases.each do |c|
          c.actor.take
        rescue => e
          c.exception = e.cause
        ensure
          runner.handle_result(c)
        end

        runner.run_execution
      end
    end
  end
end
