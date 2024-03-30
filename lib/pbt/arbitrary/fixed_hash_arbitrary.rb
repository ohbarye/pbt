# frozen_string_literal: true

module Pbt
  module Arbitrary
    class FixedHashArbitrary
      # @param hash [Hash<Symbol->Pbt::Arbitrary>]
      def initialize(hash)
        @keys = hash.keys
        @arb = TupleArbitrary.new(*hash.values)
      end

      # @return [Array]
      def generate(rng)
        values = @arb.generate(rng)
        @keys.zip(values).to_h
      end

      # @return [Enumerator]
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
