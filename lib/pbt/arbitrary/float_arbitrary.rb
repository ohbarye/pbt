# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates finite Float values and shrinks them toward zero.
    class FloatArbitrary < MapArbitrary
      def initialize(arb)
        super(arb, FLOAT_MAPPER, FLOAT_UNMAPPER)
      end

      # @see Arbitrary#cover?
      def cover?(value)
        value.is_a?(Float) && value.finite?
      end
    end
  end
end
