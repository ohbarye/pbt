# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates one of the given choices.
    class OneOfArbitrary < Arbitrary
      # @param choices [Array] List of choices.
      def initialize(choices)
        @choices = choices
        @idx_arb = IntegerArbitrary.new(0, choices.size - 1)
      end

      # @see Arbitrary#generate
      def generate(rng)
        @choices[@idx_arb.generate(rng)]
      end

      # @see Arbitrary#shrink
      def shrink(current)
        # Shrinks to values earlier in the list of `choices`.
        Enumerator.new do |y|
          @idx_arb.shrink(@choices.index(current)).map do |idx|
            y << @choices[idx]
          end
        end
      end
    end
  end
end
