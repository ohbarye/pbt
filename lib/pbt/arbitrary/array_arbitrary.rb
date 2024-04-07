# frozen_string_literal: true

module Pbt
  module Arbitrary
    class ArrayArbitrary < Arbitrary
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

      # Returns shrunken arrays.
      # This doesn't produce all possible patterns because it could be too large (+1000) even for small arrays.
      # @param current [Array]
      # @return [Enumerator]
      def shrink(current)
        return Enumerator.new { |_| } if current.size == @min_length

        Enumerator.new do |y|
          @length_arb.shrink(current.size).each do |length|
            if length == 0
              y.yield []
              next
            end
            current.each_cons(length) do |con|
              y.yield con
            end
          end

          current.each_with_index do |item, i|
            @arbitrary.shrink(item).each do |val|
              y.yield [*current[...i], val, *current[i + 1..]]
            end
          end
        end
      end
    end
  end
end
