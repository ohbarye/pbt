# frozen_string_literal: true

module Pbt
  module Check
    Configuration = Struct.new(
      :verbose,
      :use_ractor,
      :num_runs,
      :seed,
      keyword_init: true
    ) do
      def initialize(
        verbose: false,
        use_ractor: true,
        num_runs: 100,
        seed: Random.new.seed
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
