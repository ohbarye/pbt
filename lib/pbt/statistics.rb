# frozen_string_literal: true

module Pbt
  # Distribution of an independent, seeded sample of generated values.
  class Statistics
    attr_reader :seed, :num_runs, :counts

    def initialize(arbitrary, num_runs:, seed:, &classifier)
      unless num_runs.is_a?(Integer) && num_runs >= 0
        raise ArgumentError, "num_runs must be a nonnegative Integer"
      end
      @seed = seed
      @num_runs = num_runs
      @counts = Hash.new(0)
      rng = Random.new(seed)
      num_runs.times do
        value = arbitrary.generate(rng)
        label = classifier ? classifier.call(value) : value
        @counts[label] += 1
      end
    end

    # Percentages are not rounded. Empty samples return an empty Hash.
    def percentages
      counts.transform_values { |count| count * 100.0 / num_runs }
    end
  end
end
