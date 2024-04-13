# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a constant value.
    class ConstantArbitrary < Arbitrary
      # @param val [Object]
      def initialize(val)
        @val = val
      end

      # @see Arbitrary#generate
      def generate(rng)
        @val
      end

      # @see Arbitrary#shrink
      def shrink(current)
        Enumerator.new {}
      end
    end
  end
end
