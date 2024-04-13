# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a random value from a range.
    class ChooseArbitrary < Arbitrary
      # @param range [Range<Integer>]
      def initialize(range)
        @range = range
      end

      # @see Arbitrary#generate
      def generate(rng)
        rng.rand(@range)
      end

      # @see Arbitrary#shrink
      def shrink(current)
        # Range is ordered from min to max, so we can just shrink towards min.
        min, max = [@range.begin, @range.end].sort
        IntegerArbitrary.new(min, max).shrink(current, target: min)
      end
    end
  end
end
