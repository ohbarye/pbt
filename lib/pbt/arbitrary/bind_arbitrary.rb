# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates dependent values by passing values from an outer arbitrary into a binder
    # that returns an inner arbitrary. Shrinking uses `Sample` provenance to shrink both
    # the outer choice and the dependent inner value together.
    class BindArbitrary < Arbitrary
      # @param arb [Arbitrary] Outer arbitrary.
      # @param binder [#call] Callable returning an inner arbitrary for each outer value.
      def initialize(arb, binder)
        raise ArgumentError, "binder must be callable" unless binder.respond_to?(:call)

        @arb = arb
        @binder = binder
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        outer_val = @arb.generate(rng)
        inner_seed = rng.rand(1 << 64)
        inner_arb = Sample.validate_bound_arbitrary!(@binder.call(outer_val))
        inner_arb.generate(Random.new(inner_seed))
      end

      # @private
      def contextual?
        true
      end

      # @see Arbitrary#sample
      def sample(rng = Random.new)
        outer_sample = Sample.capture(@arb, rng)
        inner_seed = rng.rand(1 << 64)
        Sample.bind(outer_sample, inner_seed) { |v| @binder.call(v) }
      end

      # Conservative 3-valued membership check (cannot determine dependent codomain in general).
      #
      # @see Arbitrary#cover?
      def cover?(_value)
        nil
      end

      # A bare value cannot identify the outer choice that produced its inner arbitrary.
      # Use `sample`, `Pbt.property`, or `Pbt.stateful` to shrink.
      #
      # @see Arbitrary#shrink
      def shrink(_current)
        [].each
      end
    end
  end
end
