# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::MapArbitrary do
  describe "#initialize" do
    it do
      arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
      expect(arb).to be_a(Pbt::Arbitrary::MapArbitrary)
    end
  end

  describe "#generate" do
    it "generates mapped values of given arbitrary" do
      val = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i }).generate(Random.new)
      expect(val).to be_a(String)
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates halved arrays" do
      arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
      expect(arb.shrink("50").to_a).to eq ["25", "13", "7", "4", "2", "1", "0"]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
        expect(arb.shrink("0").to_a).to eq []
      end
    end
  end
end
