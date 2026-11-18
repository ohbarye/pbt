# frozen_string_literal: true

require "pbt"

# ASCII characters are representable in all three encodings. Change the alphabet
# to a known representable set when testing non-ASCII characters for one encoding.
["UTF-8", "ISO-8859-1", "Shift_JIS"].each do |encoding|
  strings = Pbt.ascii_string.map(
    ->(value) { value.encode(encoding) },
    ->(value) { value.encode("UTF-8") }
  )
  Pbt.assert(seed: 42, num_runs: 100) do
    Pbt.property(strings) do |value|
      raise "invalid encoding" unless value.encoding == Encoding.find(encoding) && value.valid_encoding?
      raise "round trip failed" unless value.encode("UTF-8").encode(encoding) == value
    end
  end
end
puts "100 cases passed for each encoding"
