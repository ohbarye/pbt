# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::TupleArbitrary do
  describe "#generate" do
    it "generates an array" do
      val = Pbt::Arbitrary::TupleArbitrary.new(Pbt.integer, Pbt.integer).generate(Random.new)
      expect(val).to be_a(Array)
    end

    it "generates an array of given arbitrary" do
      val = Pbt::Arbitrary::TupleArbitrary.new(Pbt.integer, Pbt.integer).generate(Random.new)
      val.each { |e| expect(e).to be_a(Integer) }
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::TupleArbitrary.new(Pbt.integer)
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that returns shrunken values" do
      arb = Pbt::Arbitrary::TupleArbitrary.new(Pbt.integer)
      expect(arb.shrink([50]).to_a).to eq [
        [25],
        [13],
        [7],
        [4],
        [2],
        [1],
        [0]
      ]
    end

    it "returns an Enumerator that returns shrunken values for each arbitraries" do
      arb = Pbt::Arbitrary::TupleArbitrary.new(Pbt.integer, Pbt.integer)
      expect(arb.shrink([10, 20]).to_a).to eq [
        [5, 20],
        [3, 20],
        [2, 20],
        [1, 20],
        [0, 20],
        [10, 10],
        [10, 5],
        [10, 3],
        [10, 2],
        [10, 1],
        [10, 0]
      ]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::TupleArbitrary.new(Pbt.integer, Pbt.integer)
        expect(arb.shrink([0, 0]).to_a).to eq []
      end
    end
  end
end
