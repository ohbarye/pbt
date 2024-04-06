# frozen_string_literal: true

module Pbt
  module Arbitrary
    class ConstantArbitrary < Arbitrary
      # @param val [Object
      def initialize(val)
        @val = val
      end

      # @return [Object]
      def generate(rng)
        @val
      end

      # @return [Enumerator]
      def shrink(current)
        Enumerator.new {}
      end
    end
  end
end
