# frozen_string_literal: true

require "pbt/arbitrary/arbitrary"
require "pbt/arbitrary/constant"
require "pbt/arbitrary/array_arbitrary"
require "pbt/arbitrary/integer_arbitrary"
require "pbt/arbitrary/tuple_arbitrary"
require "pbt/arbitrary/fixed_hash_arbitrary"
require "pbt/arbitrary/choose_arbitrary"
require "pbt/arbitrary/one_of_arbitrary"
require "pbt/arbitrary/map_arbitrary"
require "pbt/arbitrary/filter_arbitrary"

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

      # @param arbs [Array<Pbt::Arbitrary>
      def tuple(*arbs)
        TupleArbitrary.new(*arbs)
      end

      # @param hash [Hash<Symbol->Pbt::Arbitrary>]
      def fixed_hash(hash)
        FixedHashArbitrary.new(hash)
      end

      # @param range [Range<Integer>]
      def choose(range)
        ChooseArbitrary.new(range)
      end

      # @param choices [Array]
      def one_of(*choices)
        OneOfArbitrary.new(choices)
      end

      # Generates a single unicode character (including printable and non-printable).
      def char
        choose(0..0x10FFFF).map(CHAR_MAPPER, CHAR_UNMAPPER)
      end

      def alphanumeric_char
        one_of(*ALPHANUMERIC_CHARS)
      end

      def alphanumeric_string(**kwargs)
        array(alphanumeric_char, **kwargs).map(STRING_MAPPER, STRING_UNMAPPER)
      end

      def ascii_char
        one_of(*ASCII_CHARS)
      end

      def ascii_string(**kwargs)
        array(ascii_char, **kwargs).map(STRING_MAPPER, STRING_UNMAPPER)
      end

      def printable_ascii_char
        one_of(*PRINTABLE_ASCII_CHARS)
      end

      def printable_ascii_string(**kwargs)
        array(printable_ascii_char, **kwargs).map(STRING_MAPPER, STRING_UNMAPPER)
      end

      def printable_char
        one_of(*PRINTABLE_CHARS)
      end

      def printable_string(**kwargs)
        array(printable_char, **kwargs).map(STRING_MAPPER, STRING_UNMAPPER)
      end

      def symbol(**kwargs)
        array(one_of(*SYMBOL_SAFE_CHARS), **kwargs).map(SYMBOL_MAPPER, SYMBOL_UNMAPPER)
      end
    end
  end
end
