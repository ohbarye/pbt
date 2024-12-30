# frozen_string_literal: true

require "pbt/check/runner_iterator"
require "pbt/check/tosser"
require "pbt/check/case"
require "pbt/reporter/run_details_reporter"

module Pbt
  module Check
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

        initial_values = toss(property, config[:seed])
        source_values = Enumerator.new(config[:num_runs]) do |y|
          config[:num_runs].times do
            y.yield initial_values.next
          end
        end

        setup_for_ractor(config, property) do
          run_it(property, source_values, config).to_run_details(config)
        end
      end

      private

      # If using Ractor, some extra configurations are available and they need to be set up.
      #
      # - `:thread_report_on_exception`
      #   So many exception reports happen in Ractor and a console gets too messy. Suppress them to avoid that.
      # - `:experimental_ractor_rspec_integration`
      #   Allow to use Ractor with RSpec. This is an experimental feature and it's not stable.
      #
      # @param config [Hash] Configuration parameters.
      # @param property [Property]
      # @param block [Proc]
      def setup_for_ractor(config, property, &block)
        if config[:worker] == :ractor
          original_report_on_exception = Thread.report_on_exception
          Thread.report_on_exception = config[:thread_report_on_exception]

          if config[:experimental_ractor_rspec_integration]
            require "pbt/check/rspec_adapter/integration"
            class << property
              include Pbt::Check::RSpecAdapter::PropertyExtension
            end
            property.setup_rspec_integration
          end
        end

        yield
      ensure
        if config[:worker] == :ractor
          Thread.report_on_exception = original_report_on_exception
          property.teardown_rspec_integration if config[:experimental_ractor_rspec_integration]
        end
      end

      # Run the property test for each value.
      #
      # @param property [Property] Property to test.
      # @param source_values [Enumerator] Enumerator of values to test.
      # @param config [Hash] Configuration parameters.
      # @return [RunExecution] Result of the test.
      def run_it(property, source_values, config)
        runner = Check::RunnerIterator.new(source_values, property, config[:verbose])
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
          c = Case.new(val:, index:)
          begin
            property.run(val)
            runner.handle_result(c)
          # Catch all exceptions including RSpec's ExpectationNotMet (It inherits Exception).
          rescue Exception => e # standard:disable Lint/RescueException:
            c.exception = e
            runner.handle_result(c)
            break # Ignore the rest of the cases. Just pick up the first failure.
          end
        end
      end

      # @param property [Property] Property to test.
      # @param runner [RunnerIterator]
      # @return [void]
      def run_it_in_ractors(property, runner)
        runner.map.with_index { |val, index|
          Case.new(val:, index:, ractor: property.run_in_ractor(val))
        }.each do |c|
          c.ractor.take
          runner.handle_result(c)
        rescue => e
          handle_ractor_error(e.cause, c)
          runner.handle_result(c)
          break # Ignore the rest of the cases. Just pick up the first failure.
        end
      end

      def handle_ractor_error(cause, c)
        # Ractor error is wrapped in a Ractor::RemoteError. We need to get the cause.
        unless defined?(Pbt::Check::RSpecAdapter) && cause.is_a?(Pbt::Check::RSpecAdapter::ExpectationNotMet) # Unknown error.
          c.exception = cause
          return
        end

        # Convert Pbt's custom error to RSpec's error.
        begin
          RSpec::Expectations::ExpectationHelper.handle_failure(cause.matcher, cause.custom_message, cause.failure_message_method)
        rescue RSpec::Expectations::ExpectationNotMetError => e # The class inherits Exception, not StandardError.
          c.exception = e
        end
      end
    end
  end
end
