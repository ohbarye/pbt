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
      def generate(rng = Random.new)
        rng.rand(@range)
      end

      # @see Arbitrary#cover?
      def cover?(value)
        if integer_range?
          return false unless value.is_a?(Integer)
        elsif !value.is_a?(Numeric)
          return false
        end

        @range.cover?(value)
      end

      # @see Arbitrary#shrink
      def shrink(current)
        # Range is ordered from min to max, so we can just shrink towards min.
        min, max = [@range.begin, @range.end].sort
        IntegerArbitrary.new(min, max).shrink(current, target: min)
      end

      private

      def integer_range?
        @range.begin.is_a?(Integer) && (@range.end.nil? || @range.end.is_a?(Integer))
      end
    end
  end
end
