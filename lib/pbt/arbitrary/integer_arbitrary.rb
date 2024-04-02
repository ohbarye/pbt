# frozen_string_literal: true

module Pbt
  module Arbitrary
    class IntegerArbitrary < Arbitrary
      DEFAULT_TARGET = 0
      DEFAULT_SIZE = 1000000

      # @param min [Integer]
      # @param max [Integer]
      def initialize(min = nil, max = nil)
        @max = max || DEFAULT_SIZE
        @min = min || -DEFAULT_SIZE
      end

      # @return [Integer]
      def generate(rng)
        rng.rand(@min..@max)
      end

      # @return [Enumerator]
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
