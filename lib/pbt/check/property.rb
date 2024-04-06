# frozen_string_literal: true

module Pbt
  module Check
    class Property
      # @param arb [Array<Pbt::Arbitrary>]
      # @param predicate [Proc]
      def initialize(arb, &predicate)
        @arb = arb
        @predicate = predicate
      end

      # @param rng [Random]
      # @return [Object]
      def generate(rng)
        @arb.generate(rng)
      end

      # @param val [Object]
      # @return [Object]
      def shrink(val)
        @arb.shrink(val)
      end

      # @param val [Object]
      # @return [void]
      def run(val)
        @predicate.call(val)
      end

      # @param val [Object]
      # @return [Ractor]
      def run_in_ractor(val)
        Ractor.new(val, &@predicate)
      end
    end
  end
end
