# frozen_string_literal: true

require "pbt/arbitrary/arbitrary"
require "pbt/arbitrary/constant"
require "pbt/arbitrary/constant_arbitrary"
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
        integer(min: 0, max: max)
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

      # One lowercase hexadecimal character
      def hexa
        one_of(*HEXA_CHARS)
      end

      def hexa_string(**kwargs)
        array(hexa, **kwargs).map(STRING_MAPPER, STRING_UNMAPPER)
      end

      # Generates a single unicode character (including printable and non-printable).
      def char
        choose(CHAR_RANGE).map(CHAR_MAPPER, CHAR_UNMAPPER)
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

      def float
        tuple(integer, integer).map(FLOAT_MAPPER, FLOAT_UNMAPPER)
      end

      def set(arbitrary, min: 0, max: nil, empty: true)
        array(arbitrary, min: min, max: max, empty: empty).map(SET_MAPPER, SET_UNMAPPER)
      end

      def hash(*args, **kwargs)
        if args.size == 2
          key_arbitrary, value_arbitrary = args
          array(tuple(key_arbitrary, value_arbitrary), **kwargs).map(HASH_MAPPER, HASH_UNMAPPER)
        else
          super # call `Object#hash`
        end
      end

      def boolean
        one_of(true, false)
      end

      # @param val [Object]
      def constant(val)
        ConstantArbitrary.new(val)
      end

      def nil
        constant(nil)
      end

      def date(base_date: Date.today, past_offset_days: -18250, future_offset_days: 18250)
        offset_arb = integer(min: past_offset_days, max: future_offset_days)
        offset_arb.map(DATE_MAPPER.call(base_date), DATE_UNMAPPER.call(base_date))
      end

      def past_date(base_date: Date.today, past_offset_days: -18250)
        date(base_date: base_date, past_offset_days: past_offset_days, future_offset_days: 0)
      end

      def future_date(base_date: Date.today, future_offset_days: 18250)
        date(base_date: base_date, past_offset_days: 0, future_offset_days: future_offset_days)
      end

      def time(base_time: Time.now, past_offset_seconds: -1576800000, future_offset_seconds: 1576800000)
        offset_arb = integer(min: past_offset_seconds, max: future_offset_seconds)
        offset_arb.map(TIME_MAPPER.call(base_time), TIME_UNMAPPER.call(base_time))
      end

      def past_time(base_time: Time.now, past_offset_seconds: -1576800000)
        time(base_time: base_time, past_offset_seconds: past_offset_seconds, future_offset_seconds: 0)
      end

      def future_time(base_time: Time.now, future_offset_seconds: 1576800000)
        time(base_time: base_time, past_offset_seconds: 0, future_offset_seconds: future_offset_seconds)
      end
    end
  end
end
