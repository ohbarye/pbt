# frozen_string_literal: true

module Pbt
  module Check
    Configuration = Struct.new(
      :verbose,
      :concurrency_method,
      :num_runs,
      :seed,
      :thread_report_on_exception,
      keyword_init: true
    ) do
      def initialize(
        verbose: false,
        concurrency_method: :ractor,
        num_runs: 100,
        seed: Random.new.seed,
        thread_report_on_exception: true
      )
        super
      end
    end

    module ConfigurationMethods
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end
    end
  end
end
