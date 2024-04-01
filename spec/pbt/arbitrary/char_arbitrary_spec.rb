# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::CharArbitrary do
  describe "#generate" do
    it "generates an character" do
      val = Pbt::Arbitrary::CharArbitrary.new.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::CharArbitrary.new
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates characters shrinking towards lower codepoint" do
      arb = Pbt::Arbitrary::CharArbitrary.new
      expect(arb.shrink("z").to_a).to eq ["=", "\u001F", "\u0010", "\b", "\u0004", "\u0002", "\u0001", "\u0000"]
    end
  end
end
