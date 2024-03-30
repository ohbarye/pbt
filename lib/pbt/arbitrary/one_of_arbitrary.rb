# frozen_string_literal: true

module Pbt
  module Arbitrary
    class OneOfArbitrary
      # @param choices [Array]
      def initialize(choices)
        @choices = choices
        @idx_arb = IntegerArbitrary.new(0, choices.size - 1)
      end

      # @return [Array]
      def generate(rng)
        @choices[@idx_arb.generate(rng)]
      end

      # Shrinks to values earlier in the list of `choices`.
      # @return [Enumerator]
      def shrink(current)
        Enumerator.new do |y|
          @idx_arb.shrink(@choices.index(current)).map do |idx|
            y << @choices[idx]
          end
        end
      end
    end
  end
end
