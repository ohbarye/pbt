# frozen_string_literal: true

module Pbt
  module Check
    # Configuration for Pbt.
    Configuration = Struct.new(
      :verbose,
      :worker,
      :num_runs,
      :seed,
      :thread_report_on_exception,
      keyword_init: true
    ) do
      # @param verbose [Boolean] Whether to print verbose output. Default is `false`.
      # @param worker [Symbol] The concurrency method to use. :ractor`, `:thread`, `:process` and `:none` are supported. Default is `:ractor`.
      # @param num_runs [Integer] The number of runs to perform. Default is `100`.
      # @param seed [Integer] The seed to use for random number generation. It's useful to reproduce failed test with the seed you'd pick up from failure messages. Default is a random seed.
      # @param thread_report_on_exception [Boolean] Whether to report exceptions in threads. It's useful to suppress error logs on Ractor that reports many errors. Default is `false`.
      def initialize(
        verbose: false,
        worker: :ractor,
        num_runs: 100,
        seed: Random.new.seed,
        thread_report_on_exception: false
      )
        super
      end
    end

    module ConfigurationMethods
      # Return the current configuration.
      # If you modify the configuration, it will affect all future property-based tests.
      #
      # @example
      #   config = Pbt.configuration
      #   config.num_runs = 20
      #
      # @return [Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # Return the current configuration.
      # If you modify the configuration, it will affect all future property-based tests.
      #
      # @example
      #   Pbt.configure do |config|
      #     config.num_runs = 20
      #   end
      #
      # @yield [configuration] The current configuration.
      # @yieldparam configuration [Configuration]
      def configure
        yield(configuration)
      end
    end
  end
end
