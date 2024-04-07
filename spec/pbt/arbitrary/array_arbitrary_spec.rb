# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ArrayArbitrary do
  describe "#initialize" do
    it "does not allow negative min" do
      expect { Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer, -1) }.to raise_error(ArgumentError)
    end
  end

  describe "#generate" do
    it "generates an array" do
      val = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer).generate(Random.new)
      expect(val).to be_a(Array)
    end

    it "generates an array of given arbitrary" do
      val = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer).generate(Random.new)
      val.each { |e| expect(e).to be_a(Integer) }
    end

    it "allows to specify size with min and max" do
      aggregate_failures do
        100.times do
          val = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer, 1, 4).generate(Random.new)
          expect(val.size).to be >= 1
          expect(val.size).to be <= 4
        end
      end
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer)
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates arrays with shrunken length or value" do
      arb = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer)
      expect(arb.shrink([3]).to_a).to eq [[], [2], [1], [0]]
      expect(arb.shrink([2, 0]).to_a).to eq [[2], [0], [], [1, 0], [0, 0]]
      expect(arb.shrink([13, 7, 9]).to_a).to eq [
        [13, 7],
        [7, 9],
        [13],
        [7],
        [9],
        [],
        [7, 7, 9],
        [4, 7, 9],
        [2, 7, 9],
        [1, 7, 9],
        [0, 7, 9],
        [13, 4, 9],
        [13, 2, 9],
        [13, 1, 9],
        [13, 0, 9],
        [13, 7, 5],
        [13, 7, 3],
        [13, 7, 2],
        [13, 7, 1],
        [13, 7, 0]
      ]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer)
        expect(arb.shrink([]).to_a).to eq []
      end
    end
  end
end
