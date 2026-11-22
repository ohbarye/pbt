# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates finite Float values via `x.to_f / (y.to_f.abs + 1.0)` over default integer bounds
    # and shrinks them toward zero.
    class FloatArbitrary < MapArbitrary
      MAX_ABS = 1_000_000.0
      MIN_NONZERO_ABS = 1.0 / 1_000_001.0
      private_constant :MAX_ABS, :MIN_NONZERO_ABS

      def initialize
        super(
          TupleArbitrary.new(IntegerArbitrary.new(-1_000_000, 1_000_000), IntegerArbitrary.new(-1_000_000, 1_000_000)),
          FLOAT_MAPPER,
          FLOAT_UNMAPPER
        )
      end

      # @see Arbitrary#cover?
      def cover?(value)
        return false unless value.is_a?(Float) && value.finite?
        return false if value.abs > MAX_ABS
        return true if value == 0.0
        return false if value.abs < MIN_NONZERO_ABS

        nil
      end
    end
  end
end
