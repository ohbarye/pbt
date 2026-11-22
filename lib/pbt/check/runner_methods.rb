# frozen_string_literal: true

require "pbt/check/runner_iterator"
require "pbt/check/tosser"
require "pbt/check/case"
require "pbt/reporter/run_details_reporter"

module Pbt
  module Check
    # Exceptions that must never be treated as property failures or swallowed during shrinking.
    FATAL_EXCEPTIONS = [SystemExit, SignalException, NoMemoryError].freeze

    # Module to be
    module RunnerMethods
      include Check::Tosser

      # Run a property based test and report its result.
      #
      # @see Check::Configuration
      # @param options [Hash] Optional parameters to customize the execution.
      # @param property [Proc] Proc that returns Property instance.
      # @return [void]
      # @raise [PropertyFailure]
      def assert(**options, &property)
        out = check(**options, &property)
        Reporter::RunDetailsReporter.new(out).report_run_details
      end

      # Run a property based test and return its result.
      # This doesn't throw contrary to `assert`.
      # Use `assert` unless you want to handle the result.
      #
      # @see RunnerMethods#assert
      # @see Check::Configuration
      # @param options [Hash] Optional parameters to customize the execution.
      # @param property [Proc] Proc that returns Property instance.
      # @return [RunDetails]
      def check(**options, &property)
        property = property.call
        config = Pbt.configuration.to_h.merge(options.to_h)

        if property.respond_to?(:stateful?) && property.stateful? && !options.key?(:worker)
          config[:worker] = :none
        end

        max_skips = config[:max_skips]
        if !max_skips.nil? && !(max_skips.is_a?(Integer) && max_skips >= 0)
          raise Pbt::InvalidConfiguration, "max_skips must be a non-negative Integer or nil"
        end

        initial_values = toss(property, config[:seed])

        setup_for_ractor(config, property) do
          run_it(property, initial_values, config).to_run_details(config)
        end
      end

      private

      # If using Ractor, some extra configurations are available and they need to be set up.
      #
      # - `:thread_report_on_exception`
      #   So many exception reports happen in Ractor and a console gets too messy. Suppress them to avoid that.
      #
      # @param config [Hash] Configuration parameters.
      # @param property [Property]
      # @param block [Proc]
      def setup_for_ractor(config, property, &block)
        if config[:worker] == :ractor
          original_report_on_exception = Thread.report_on_exception
          Thread.report_on_exception = config[:thread_report_on_exception]
        end

        yield
      ensure
        if config[:worker] == :ractor
          Thread.report_on_exception = original_report_on_exception
        end
      end

      # Run the property test for each value.
      #
      # @param property [Property] Property to test.
      # @param source_values [Enumerator] Infinite enumerator of values to test.
      # @param config [Hash] Configuration parameters.
      # @return [RunExecution] Result of the test.
      def run_it(property, source_values, config)
        max_skips = config[:max_skips].nil? ? config[:num_runs] * 10 : config[:max_skips]
        runner = Check::RunnerIterator.new(
          source_values,
          property,
          config[:verbose],
          target_runs: config[:num_runs],
          max_skips: max_skips
        )
        while runner.has_next?
          case config[:worker]
          in :none
            run_it_in_sequential(property, runner)
          in :ractor
            run_it_in_ractors(property, runner)
          end
        end
        runner.run_execution
      end

      # @param property [Property] Property to test.
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_sequential(property, runner)
        runner.each_with_index do |val, index|
          c = build_case(val, runner.case_index(index))
          begin
            property.run(c.val)
            runner.handle_result(c)
          rescue PreconditionNotMet
            break if runner.handle_skip
          rescue *FATAL_EXCEPTIONS
            raise
          # Catch all other exceptions including RSpec's ExpectationNotMet (It inherits Exception).
          rescue Exception => e # standard:disable Lint/RescueException:
            c.exception = e
            break if runner.handle_result(c) # Ignore the rest of the cases when failure is accepted.
          end
        end
      end

      # @param property [Property] Property to test.
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_ractors(property, runner)
        runner.map.with_index { |val, index|
          c = build_case(val, runner.case_index(index))
          c.ractor = property.run_in_ractor(c.val)
          c
        }.each do |c|
          wait_ractor_result(c.ractor)
          runner.handle_result(c)
        rescue => e
          cause = unwrap_ractor_exception(e)
          if cause.is_a?(PreconditionNotMet)
            break if runner.handle_skip

            next
          end
          raise cause if FATAL_EXCEPTIONS.any? { |klass| cause.is_a?(klass) }

          c.exception = cause
          break if runner.handle_result(c) # Ignore the rest of the cases when failure is accepted.
        end
      end

      def build_case(value, index)
        if value.is_a?(Arbitrary::Sample)
          Case.new(val: value.value, sample: value, index: index)
        else
          Case.new(val: value, index: index)
        end
      end

      # Ractor errors can wrap the original exception in a `cause` (e.g. `Ractor::RemoteError`).
      # If no cause exists, keep the original exception instance.
      #
      # @param error [Exception]
      # @return [Exception]
      def unwrap_ractor_exception(error)
        error.cause || error
      end

      # Ruby 4 removed Ractor#take in favor of Ractor#value.
      #
      # @param ractor [Ractor]
      # @return [Object]
      def wait_ractor_result(ractor)
        if ractor.respond_to?(:value)
          ractor.value
        else
          ractor.take
        end
      end
    end
  end
end
