# frozen_string_literal: true

module Pbt
  module Arbitrary
    class FilterArbitrary < Arbitrary
      # @param arb [ArrayArbitrary]
      # @param refinement [Proc] a function to filter the generated value and shrunken values.
      #
      def initialize(arb, &refinement)
        @arb = arb
        @refinement = refinement
      end

      # @return [Array]
      def generate(rng)
        loop do
          val = @arb.generate(rng)
          return val if @refinement.call(val)
        end
      end

      # @return [Enumerator]
      def shrink(current)
        Enumerator.new do |y|
          @arb.shrink(current).each do |v|
            if @refinement.call(v)
              y.yield v
            else
              next
            end
          end
        end
      end
    end
  end
end
