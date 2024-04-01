# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ArbitraryMethods do
  describe ".printable_ascii_char" do
    it "generates a character" do
      val = Pbt.printable_ascii_char.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end

    it "is printable ascii char" do
      val = Pbt.printable_ascii_char.generate(Random.new)
      expect(Pbt::Arbitrary::PRINTABLE_ASCII_CHARS).to include(val)
    end
  end
end
