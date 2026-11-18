# frozen_string_literal: true

require "pbt"

# Twenty values in each interval; shrinking occurs in the index domain.
numbers = Pbt.integer(min: 0, max: 39).map(
  ->(index) { (index < 20) ? index + 1 : index + 20 },
  ->(value) { (value <= 20) ? value - 1 : value - 20 }
)
Pbt.assert(seed: 42, num_runs: 100) do
  Pbt.property(numbers) do |value|
    raise "outside intervals" unless (1..20).cover?(value) || (40..59).cover?(value)
  end
end
puts "100 cases passed for disjoint ranges"
