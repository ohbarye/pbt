# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a hash with fixed keys and arbitrary values.
    class FixedHashArbitrary < Arbitrary
      # @param hash [Hash<Object, Arbitrary<T>>] Hash with any keys and arbitraries as values.
      def initialize(hash)
        @keys = hash.keys
        @arb = TupleArbitrary.new(*hash.values)
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        values = @arb.generate(rng)
        @keys.zip(values).to_h
      end

      def contextual?
        Sample.contextual?(@arb)
      end

      def sample(rng = Random.new)
        @arb.sample(rng).map { |values| @keys.zip(values).to_h }
      end

      # @see Arbitrary#cover?
      def cover?(value)
        return false unless value.is_a?(Hash) && value.size == @keys.size
        return false unless @keys.all? { |k| value.key?(k) }

        @arb.cover?(@keys.map { |k| value[k] })
      end

      # @see Arbitrary#shrink
      def shrink(current)
        # This is not the most comprehensive but allows a reasonable number of entries in the shrink
        Enumerator.new do |y|
          @arb.shrink(current.values).each do |next_values|
            y << @keys.zip(next_values).to_h
          end
        end
      end
    end
  end
end
