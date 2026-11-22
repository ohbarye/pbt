# frozen_string_literal: true

module Pbt
  module Check
    # Represents a property to be tested.
    # This class holds an arbitrary to generate values and a predicate to test them.
    class Property
      # @param arb [Arbitrary]
      # @param keyword_args [Boolean] Whether generated Hash values should be splatted as keyword arguments.
      # @param splat_args [Boolean] Whether generated tuple values should be splatted as positional arguments.
      # @param predicate [Proc] Predicate proc to test the generated values. Library users write this.
      def initialize(arb, keyword_args: false, splat_args: false, &predicate)
        @arb = arb
        @keyword_args = keyword_args
        @splat_args = splat_args
        @predicate = predicate
      end

      # Generate a next value to test.
      #
      # @param rng [Random] Random number generator.
      # @return [Object]
      def generate(rng = Random.new)
        @arb.generate(rng)
      end

      # @private Generate with provenance only when a composite needs it.
      def generate_for_check(rng)
        if Arbitrary::Sample.contextual?(@arb)
          Arbitrary::Sample.capture(@arb, rng)
        else
          generate(rng)
        end
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
        if @keyword_args
          @predicate.call(**val)
        elsif @splat_args
          @predicate.call(*val)
        else
          @predicate.call(val)
        end
      end

      # Run the predicate with the generated `val` in a Ractor.
      # This is used only for parallel testing with Ractors.
      #
      # @param val [Object]
      # @return [Ractor]
      def run_in_ractor(val)
        if @splat_args
          Ractor.new(*val, &@predicate)
        else
          Ractor.new(val, &@predicate)
        end
      end
    end
  end
end
