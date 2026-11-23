# frozen_string_literal: true

require "date"

module Pbt
  module Arbitrary
    HEXA_CHARS = [*("0".."9"), *("a".."f")].freeze
    SYMBOL_SAFE_CHARS = [*("a".."z"), "-"].freeze
    ALPHANUMERIC_CHARS = [*("a".."z"), *("A".."Z"), *("0".."9")].freeze
    PRINTABLE_ASCII_CHARS = [*(" ".."~")].freeze
    ASCII_CHARS = [*PRINTABLE_ASCII_CHARS, "\n", "\r", "\t", "\v", "\b", "\f", "\e", "\x7F", "\a"].freeze

    # Valid Unicode scalar values exclude UTF-16 surrogates (0xD800..0xDFFF).
    SURROGATE_START = 0xD800
    SURROGATE_COUNT = 0x800
    UNICODE_SCALAR_INDEX_RANGE = (0..(0x10FFFF - SURROGATE_COUNT))

    # Printable Unicode codepoint segments (excludes C0/C1 controls, DEL, surrogates, and U+FFFE/U+FFFF).
    PRINTABLE_ASCII_CODEPOINT_RANGE = (0x20..0x7E)
    PRINTABLE_BMP_MAIN_CODEPOINT_RANGE = (0xA0..0xD7FF)
    PRINTABLE_BMP_HIGH_CODEPOINT_RANGE = (0xE000..0xFFFD)
    PRINTABLE_SUPPLEMENTARY_CODEPOINT_RANGE = (0x10000..0x10FFFF)

    CHAR_MAPPER = ->(i) {
      return nil unless i.is_a?(Integer) && UNICODE_SCALAR_INDEX_RANGE.cover?(i)

      [(i < SURROGATE_START) ? i : (i + SURROGATE_COUNT)].pack("U")
    }
    CHAR_UNMAPPER = ->(v) {
      return -1 unless v.is_a?(String) && v.valid_encoding? && v.length == 1

      cp = v.ord
      (cp < SURROGATE_START) ? cp : (cp - SURROGATE_COUNT)
    }
    CODEPOINT_MAPPER = ->(cp) {
      return nil unless cp.is_a?(Integer) && cp >= 0 && cp <= 0x10FFFF && !(cp >= SURROGATE_START && cp < SURROGATE_START + SURROGATE_COUNT)

      [cp].pack("U")
    }
    CODEPOINT_UNMAPPER = ->(v) {
      return -1 unless v.is_a?(String) && v.valid_encoding? && v.length == 1

      v.ord
    }
    STRING_MAPPER = ->(v) { v.join }
    STRING_UNMAPPER = ->(v) { v.chars }
    SYMBOL_MAPPER = ->(v) { v.join.to_sym }
    SYMBOL_UNMAPPER = ->(v) { v.to_s.chars }
    SET_MAPPER = ->(v) { v.to_set }
    SET_UNMAPPER = ->(v) { v.to_a }
    HASH_MAPPER = ->(v) { v.to_h }
    HASH_UNMAPPER = ->(v) { v.to_a }
    DATE_MAPPER = ->(epoch) { ->(v) { epoch + v } }
    DATE_UNMAPPER = ->(epoch) { ->(v) { (v - epoch).to_i } }
    TIME_MAPPER = DATE_MAPPER
    TIME_UNMAPPER = DATE_UNMAPPER

    private_constant :SURROGATE_START, :SURROGATE_COUNT, :UNICODE_SCALAR_INDEX_RANGE,
      :PRINTABLE_ASCII_CODEPOINT_RANGE, :PRINTABLE_BMP_MAIN_CODEPOINT_RANGE,
      :PRINTABLE_BMP_HIGH_CODEPOINT_RANGE, :PRINTABLE_SUPPLEMENTARY_CODEPOINT_RANGE,
      :CHAR_MAPPER, :CHAR_UNMAPPER, :CODEPOINT_MAPPER, :CODEPOINT_UNMAPPER,
      :STRING_MAPPER, :STRING_UNMAPPER, :SYMBOL_MAPPER, :SYMBOL_UNMAPPER,
      :SET_MAPPER, :SET_UNMAPPER, :HASH_MAPPER, :HASH_UNMAPPER,
      :DATE_MAPPER, :DATE_UNMAPPER, :TIME_MAPPER, :TIME_UNMAPPER
  end
end
