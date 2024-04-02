# frozen_string_literal: true

module Pbt
  module Arbitrary
    class TupleArbitrary < Arbitrary
      # @param arbs [Array<Pbt::Arbitrary>]
      def initialize(*arbs)
        @arbs = arbs
      end

      # @return [Array]
      def generate(rng)
        @arbs.map { |arb| arb.generate(rng) }
      end

      # @return [Enumerator]
      def shrink(current)
        # This is not the most comprehensive but allows a reasonable number of entries in the shrink
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
