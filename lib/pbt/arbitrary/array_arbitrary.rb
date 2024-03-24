# frozen_string_literal: true

module Pbt
  module Arbitrary
    class ArrayArbitrary
      DEFAULT_MAX_SIZE = 10

      # @param min_length [Integer]
      # @param max_length [Integer]
      def initialize(arbitrary, min_length = 0, max_length = DEFAULT_MAX_SIZE)
        raise ArgumentError, "min_length must be zero or positive number" if min_length < 0

        @min_length = min_length
        @max_length = max_length
        @arbitrary = arbitrary
        @length_arb = IntegerArbitrary.new(min_length, max_length)
      end

      # @return [Array]
      def generate(rng)
        size = @length_arb.generate(rng)
        size.times.map { @arbitrary.generate(rng) }
      end

      # @return [Enumerator]
      def shrink(current)
        return Enumerator.new { |_| } if current.size == 0

        # TODO: Implement more sophisticated shrinking. It should be shrink each item as well.
        Enumerator.new do |y|
          @length_arb.shrink(current.size).each do |length|
            slice_start = current.size - length
            y.yield current[slice_start..]
          end
        end
      end
    end
  end
end
