# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::FixedHashArbitrary do
  describe "#generate" do
    it "generates a Hash" do
      val = Pbt::Arbitrary::FixedHashArbitrary.new(x: Pbt.integer, y: Pbt.integer).generate(Random.new)
      expect(val).to be_a(Hash)
    end

    it "generates an array of given arbitrary" do
      val = Pbt::Arbitrary::FixedHashArbitrary.new(x: Pbt.integer, y: Pbt.integer).generate(Random.new)
      expect(val.keys).to eq [:x, :y]
      val.values.each { |e|
        expect(e).to be_a(Integer)
        expect(e).to be_a(Integer)
      }
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::FixedHashArbitrary.new(x: Pbt.integer)
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that returns shrunken values" do
      arb = Pbt::Arbitrary::FixedHashArbitrary.new(x: Pbt.integer)
      expect(arb.shrink({x: 50}).to_a).to eq [
        {x: 0},
        {x: 25},
        {x: 37},
        {x: 43},
        {x: 46},
        {x: 48},
        {x: 49}
      ]
    end

    it "returns an Enumerator that returns shrunken values for each arbitraries" do
      arb = Pbt::Arbitrary::FixedHashArbitrary.new(x: Pbt.integer, y: Pbt.integer)
      expect(arb.shrink({x: 10, y: 20}).to_a).to eq [
        {x: 0, y: 20},
        {x: 5, y: 20},
        {x: 7, y: 20},
        {x: 8, y: 20},
        {x: 9, y: 20},
        {x: 10, y: 0},
        {x: 10, y: 10},
        {x: 10, y: 15},
        {x: 10, y: 17},
        {x: 10, y: 18},
        {x: 10, y: 19}
      ]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::FixedHashArbitrary.new(x: Pbt.integer, y: Pbt.integer)
        expect(arb.shrink({x: 0, y: 0}).to_a).to eq []
      end
    end
  end
end
