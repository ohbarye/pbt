# frozen_string_literal: true

module Pbt
  module Check
    # Represents a property to be tested.
    # This class holds an arbitrary to generate values and a predicate to test them.
    class Property
      # @param arb [Array<Arbitrary>]
      # @param predicate [Proc] Predicate proc to test the generated values. Library users write this.
      def initialize(arb, &predicate)
        @arb = arb
        @predicate = predicate
      end

      # Generate a next value to test.
      #
      # @param rng [Random] Random number generator.
      # @return [Object]
      def generate(rng)
        @arb.generate(rng)
      end

      # Shrink the `val` to a smaller one.
      # This is used to find the smallest failing case after a failure.
      #
      # @param val [Object]
      # @return [Enumerator<Object>]
      def shrink(val)
        @arb.shrink(val)
      end

      # Run the predicate with the generated `val`.
      #
      # @param val [Object]
      # @return [void]
      def run(val)
        @predicate.call(val)
      end

      # Run the predicate with the generated `val` in a Ractor.
      # This is used only for parallel testing with Ractors.
      #
      # @param val [Object]
      # @return [Ractor]
      def run_in_ractor(val)
        Ractor.new(val, &@predicate)
      end
    end
  end
end
