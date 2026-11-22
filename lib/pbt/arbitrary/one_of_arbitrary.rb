# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Uniformly selects one of the given arbitraries and delegates generation/shrinking to it.
    class OneOfArbitrary < Arbitrary
      # @param arbitraries [Array<Arbitrary>] Non-empty list of arbitraries to choose from.
      def initialize(arbitraries)
        raise ArgumentError, "one_of expects an Array of arbitraries" unless arbitraries.is_a?(Array)
        raise EmptyDomainError, "one_of requires at least one arbitrary" if arbitraries.empty?

        unless arbitraries.all? { |arb| arb.respond_to?(:generate) && arb.respond_to?(:shrink) }
          raise ArgumentError, "one_of expects arbitraries (use Pbt.constant_from for constant values)"
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

      # @see Arbitrary#cover?
      def cover?(value)
        unknown = false
        @arbitraries.each do |arb|
          covered = arb.respond_to?(:cover?) ? arb.cover?(value) : nil
          return true if covered == true

          unknown = true if covered.nil?
        end
        unknown ? nil : false
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
