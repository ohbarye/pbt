# frozen_string_literal: true

module Pbt
  module Arbitrary
    class ChooseArbitrary < Arbitrary
      # @param range [Range<Integer>]
      def initialize(range)
        @range = range
      end

      # @return [Array]
      def generate(rng)
        rng.rand(@range)
      end

      # range is ordered from min to max, so we can just shrink towards min
      # @return [Enumerator]
      def shrink(current)
        min, max = [@range.begin, @range.end].sort
        IntegerArbitrary.new(min, max).shrink(current, target: min)
      end
    end
  end
end
