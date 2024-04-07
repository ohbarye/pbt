# frozen_string_literal: true

require "pbt/check/runner_iterator"
require "pbt/check/tosser"
require "pbt/check/case"
require "pbt/reporter/run_details_reporter"

module Pbt
  module Check
    module RunnerMethods
      include Check::Tosser

      # `assert` runs a property based test and reports its result.
      # @param options [Hash]
      # @param property [Proc]
      # @return [void]
      def assert(**options, &property)
        out = check(**options, &property)
        Reporter::RunDetailsReporter.new(out).report_run_details
      end

      # `check` runs a property based test and return its result.
      # Use `assert` unless you want to handle the result.
      # @param options [Hash]
      # @param property [Proc]
      # @return [RunDetails]
      def check(**options, &property)
        property = property.call
        config = Pbt.configuration.to_h.merge(options.to_h)

        suppress_exception_report_for_ractor(config) do
          initial_values = toss(property, config[:seed])
          source_values = Enumerator.new(config[:num_runs]) do |y|
            config[:num_runs].times do
              y.yield initial_values.next
            end
          end

          run_it(property, source_values, config).to_run_details(config)
        end
      end

      private

      # If using Ractor, so many exception reports happen in Ractor and a console gets too messy. Suppress them to avoid that.
      # @param config [Hash]
      def suppress_exception_report_for_ractor(config, &block)
        if config[:concurrency_method] == :ractor
          original_report_on_exception = Thread.report_on_exception
          Thread.report_on_exception = config[:thread_report_on_exception]
        end

        yield
      ensure
        Thread.report_on_exception = original_report_on_exception if config[:concurrency_method] == :ractor
      end

      # @param property [Proc]
      # @param source_values [Enumerator]
      # @param options [Hash]
      # @return [RunExecution]
      def run_it(property, source_values, options)
        runner = Check::RunnerIterator.new(source_values, property, options[:verbose])
        while runner.has_next?
          case options[:concurrency_method]
          in :ractor
            run_it_in_ractors(property, runner)
          in :process
            run_it_in_processes(property, runner)
          in :thread
            run_it_in_threads(property, runner)
          in :none
            run_it_in_sequential(property, runner)
          end
        end
        runner.run_execution
      end

      # @param property [Proc]
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_ractors(property, runner)
        runner.map.with_index { |val, index|
          Case.new(val:, index:, ractor: property.run_in_ractor(val))
        }.each do |c|
          c.ractor.take
          runner.handle_result(c)
        rescue => e
          c.exception = e.cause # Ractor error is wrapped in a Ractor::RemoteError. We need to get the cause.
          runner.handle_result(c)
          break # Ignore the rest of the cases. Just pick up the first failure.
        end
      end

      # @param property [Proc]
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_threads(property, runner)
        require_parallel

        Parallel.map_with_index(runner, in_threads: Parallel.processor_count) do |val, index|
          Case.new(val:, index:).tap do |c|
            property.run(val)
          rescue => e
            c.exception = e
            # It's possible to break this loop here by raising `Parallel::Break`.
            # But if it raises, we cannot fetch all cases' result. So this loop continues until the end.
          end
        end.each do |c|
          runner.handle_result(c)
          break if c.exception
          # Ignore the rest of the cases. Just pick up the first failure.
        end
      end

      # @param property [Proc]
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_processes(property, runner)
        require_parallel

        Parallel.map_with_index(runner, in_processes: Parallel.processor_count) do |val, index|
          Case.new(val:, index:).tap do |c|
            property.run(val)
          rescue => e
            c.exception = e
            # It's possible to break this loop here by raising `Parallel::Break`.
            # But if it raises, we cannot fetch all cases' result. So this loop continues until the end.
          end
        end.each do |c|
          runner.handle_result(c)
          break if c.exception
          # Ignore the rest of the cases. Just pick up the first failure.
        end
      end

      # @param property [Proc]
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_sequential(property, runner)
        runner.each_with_index do |val, index|
          c = Case.new(val:, index:)
          begin
            property.run(val)
            runner.handle_result(c)
          rescue => e
            c.exception = e
            runner.handle_result(c)
            break # Ignore the rest of the cases. Just pick up the first failure.
          end
        end
      end

      def require_parallel
        require "parallel"
      rescue
        raise InvalidConfiguration,
          "Parallel gem is required to use concurrency_method `:process` or `:thread`. Please add `gem 'parallel'` to your Gemfile."
      end
    end
  end
end
