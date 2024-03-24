# frozen_string_literal: true

require "pbt/arbitrary/array_arbitrary"
require "pbt/arbitrary/integer_arbitrary"

module Pbt
  module Arbitrary
    module ArbitraryMethods
      # @param min [Integer]
      # @param max [Integer]
      def integer(min: nil, max: nil)
        IntegerArbitrary.new(min, max)
      end

      # @param max [Integer]
      def nat(max: nil)
        IntegerArbitrary.new(0, max)
      end

      # @param arbitrary [Arbitrary]
      # @param min [Integer]
      # @param max [Integer]
      # @param empty [Boolean]
      def array(arbitrary, min: 0, max: 10, empty: true)
        raise ArgumentError if min < 0
        min = 1 if min.zero? && !empty
        ArrayArbitrary.new(arbitrary, min, max)
      end
    end
  end
end
