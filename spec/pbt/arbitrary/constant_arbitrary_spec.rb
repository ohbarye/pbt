# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ConstantArbitrary do
  describe "#generate" do
    it "generates itself" do
      val = Pbt::Arbitrary::ConstantArbitrary.new(1).generate(Random.new)
      expect(val).to be_a(Integer)
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::ConstantArbitrary.new(true)
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an empty Enumerator" do
      arb = Pbt::Arbitrary::ConstantArbitrary.new("hey")
      expect(arb.shrink("hey").to_a).to eq []
    end
  end
end
