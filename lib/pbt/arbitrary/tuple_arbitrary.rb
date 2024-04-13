# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a tuple of arbitrary values.
    class TupleArbitrary < Arbitrary
      # @param arbs [Array<Arbitrary>] Arbitraries used to generate the values of the tuple.
      def initialize(*arbs)
        @arbs = arbs
      end

      # @see Arbitrary#generate
      def generate(rng)
        @arbs.map { |arb| arb.generate(rng) }
      end

      # @see Arbitrary#shrink
      def shrink(current)
        # This is not the most comprehensive but allows a reasonable number of entries in the shrink.
        Enumerator.new do |y|
          @arbs.each_with_index do |arb, idx|
            arb.shrink(current[idx]).each do |v|
              next_values = current.dup
              next_values[idx] = v
              y << next_values
            end
          end
        end
      end
    end
  end
end
