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
      # @param name [String]
      # @param params [Hash]
      # @param property [Proc]
      # @return [void]
      def assert(name = "", params: {}, &property)
        out = check(params:, &property)
        Reporter::RunDetailsReporter.new(name, out).report_run_details
      end

      # `check` runs a property based test and return its result.
      # Use `assert` unless you want to handle the result.
      # @param params [Hash]
      # @param property [Proc]
      # @return [RunDetails]
      def check(params: {}, &property)
        property = property.call
        config = Pbt.configuration.to_h.merge(params.to_h)

        original_report_on_exception = Thread.report_on_exception
        if original_report_on_exception != config[:thread_report_on_exception]
          Thread.report_on_exception = config[:thread_report_on_exception]
        end

        initial_values = toss(property, config[:seed])
        source_values = Enumerator.new(config[:num_runs]) do |y|
          config[:num_runs].times do
            y.yield initial_values.next
          end
        end

        run_it(property, source_values, config).to_run_details(config)
      ensure
        Thread.report_on_exception = original_report_on_exception
      end

      private

      # @param property [Proc]
      # @param source_values [Enumerator]
      # @param params [Hash]
      # @return [RunExecution]
      def run_it(property, source_values, params)
        runner = Check::RunnerIterator.new(source_values, property, params[:verbose])
        while runner.has_next?
          case params[:concurrency_method]
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
        runner.map { |val|
          ractor = property.run_in_ractor(val)
          Case.new(val:, ractor:, exception: nil)
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

        cases = Parallel.map(runner.to_a, in_threads: Parallel.processor_count) do |val|
          Case.new(val: val, ractor: nil, exception: nil).tap do |c|
            property.run(val)
          rescue => e
            c.exception = e
            raise Parallel::Break, c
            # Ignore the rest of the cases. Just pick up the first failure.
          end
        end

        if cases.is_a?(Case)
          runner.handle_result(cases)
        else
          cases.each do |c|
            runner.handle_result(c)
          end
        end
      end

      # @param property [Proc]
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_processes(property, runner)
        require_parallel

        cases = Parallel.map(runner, in_processes: Parallel.processor_count) do |val|
          Case.new(val: val, ractor: nil, exception: nil).tap do |c|
            property.run(val)
          rescue => e
            c.exception = e
            raise Parallel::Break, c
            # Ignore the rest of the cases. Just pick up the first failure.
          end
        end

        if cases.is_a?(Case)
          runner.handle_result(cases)
        else
          cases.each do |c|
            runner.handle_result(c)
          end
        end
      end

      # @param property [Proc]
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_sequential(property, runner)
        runner.each do |val|
          c = Case.new(val:, ractor: nil, exception: nil)
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
