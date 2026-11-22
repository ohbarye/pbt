# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Uniformly selects one of the given arbitraries and delegates generation/shrinking to it.
    class OneOfArbitrary < Arbitrary
      # @param arbitraries [Array<Arbitrary>] Non-empty list of arbitraries to choose from.
      def initialize(arbitraries)
        unless arbitraries.is_a?(Array) && !arbitraries.empty? &&
            arbitraries.all? { |arb| arb.respond_to?(:generate) && arb.respond_to?(:shrink) }
          raise ArgumentError, "one_of expects one or more arbitraries"
        end

        @arbitraries = arbitraries.dup
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        select(rng).generate(rng)
      end

      # Preserve the selected branch for shrinking, even after subsequent generation.
      #
      # @see Arbitrary#sample
      def sample(rng = Random.new)
        Sample.capture(select(rng), rng)
      end

      # @private
      def contextual?
        true
      end

      # A bare value cannot identify its source arbitrary. Use `sample` or `Pbt.property` to shrink.
      #
      # @see Arbitrary#shrink
      def shrink(_current)
        [].each
      end

      private

      def select(rng)
        @arbitraries[rng.rand(@arbitraries.size)]
      end
    end
  end
end
