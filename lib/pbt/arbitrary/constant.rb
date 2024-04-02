# frozen_string_literal: true

module Pbt
  module Arbitrary
    ALPHANUMERIC_CHARS = [*("a".."z"), *("A".."Z"), *("0".."9")].freeze
    PRINTABLE_ASCII_CHARS = [*(" ".."~")].freeze
    ASCII_CHARS = [*PRINTABLE_ASCII_CHARS, "\n", "\r", "\t", "\v", "\b", "\f", "\e", "\d", "\a"].freeze
    PRINTABLE_CHARS = [
      *ASCII_CHARS,
      *("\u{A0}".."\u{D7FF}"),
      *("\u{E000}".."\u{FFFD}"),
      *("\u{10000}".."\u{10FFFF}")
    ].freeze
  end
end
