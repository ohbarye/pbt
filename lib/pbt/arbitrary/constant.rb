# frozen_string_literal: true

require "date"
require "set" # For 3.1 or prior. Ruby 3.2.0 has Set in the built-in library.

module Pbt
  module Arbitrary
    HEXA_CHARS = [*("0".."9"), *("a".."f")].freeze
    CHAR_RANGE = (0..0x10FFFF)
    SYMBOL_SAFE_CHARS = [*("a".."z"), "-"].freeze
    ALPHANUMERIC_CHARS = [*("a".."z"), *("A".."Z"), *("0".."9")].freeze
    PRINTABLE_ASCII_CHARS = [*(" ".."~")].freeze
    ASCII_CHARS = [*PRINTABLE_ASCII_CHARS, "\n", "\r", "\t", "\v", "\b", "\f", "\e", "\d", "\a"].freeze
    PRINTABLE_CHARS = [
      *ASCII_CHARS,
      *("\u{A0}".."\u{D7FF}"),
      *("\u{E000}".."\u{FFFD}"),
      *("\u{10000}".."\u{10FFFF}")
    ].freeze

    CHAR_MAPPER = ->(v) { [v].pack("U") }
    CHAR_UNMAPPER = ->(v) { v.unpack1("U") }
    STRING_MAPPER = ->(v) { v.join }
    STRING_UNMAPPER = ->(v) { v.chars }
    SYMBOL_MAPPER = ->(v) { v.join.to_sym }
    SYMBOL_UNMAPPER = ->(v) { v.to_s.chars }
    FLOAT_MAPPER = ->((x, y)) { x.to_f / (y.to_f.abs + 1.0) }
    FLOAT_UNMAPPER = ->(v) { [v, 0] }
    SET_MAPPER = ->(v) { v.to_set }
    SET_UNMAPPER = ->(v) { v.to_a }
    HASH_MAPPER = ->(v) { v.to_h }
    HASH_UNMAPPER = ->(v) { v.to_a }
    DATE_MAPPER = ->(epoch) { ->(v) { epoch + v } }
    DATE_UNMAPPER = ->(epoch) { ->(v) { (v - epoch).to_i } }
    TIME_MAPPER = DATE_MAPPER
    TIME_UNMAPPER = DATE_UNMAPPER
  end
end
