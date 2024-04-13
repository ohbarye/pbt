# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates random integers between `min` and `max`.
    class IntegerArbitrary < Arbitrary
      DEFAULT_TARGET = 0
      private_constant :DEFAULT_TARGET

      # @param min [Integer] Minimum value to generate.
      # @param max [Integer] Maximum value to generate.
      def initialize(min, max)
        @min = min
        @max = max
      end

      # @see Arbitrary#generate
      def generate(rng)
        rng.rand(@min..@max)
      end

      # @see Arbitrary#shrink
      def shrink(current, target: DEFAULT_TARGET)
        gap = current - target
        return Enumerator.new { |_| } if gap == 0

        is_positive_gap = gap > 0

        Enumerator.new do |y|
          while (diff = (current - target).abs) > 1
            halved = diff / 2
            current -= is_positive_gap ? halved : -halved
            y.yield current
          end
          y.yield target # no diff here
        end
      end
    end
  end
end
