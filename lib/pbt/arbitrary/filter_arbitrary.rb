# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates values from another arbitrary, but only if they pass a predicate.
    class FilterArbitrary < Arbitrary
      # @param arb [Arbitrary] Arbitrary to generate values to be filtered.
      # @param refinement [Proc] Predicate proc to test each produced element. Return true to keep the element, false otherwise.
      def initialize(arb, &refinement)
        @arb = arb
        @refinement = refinement
      end

      # @see Arbitrary#generate
      def generate(rng)
        loop do
          val = @arb.generate(rng)
          return val if @refinement.call(val)
        end
      end

      # @see Arbitrary#shrink
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
