# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::IntegerArbitrary do
  describe "#generate" do
    it "generates an integer" do
      val = Pbt::Arbitrary::IntegerArbitrary.new.generate(Random.new)
      expect(val).to be_a(Integer)
    end

    it "allows to specify range with min and max" do
      aggregate_failures do
        100.times do
          val = Pbt::Arbitrary::IntegerArbitrary.new(-3, 4).generate(Random.new)
          expect(val).to be >= -3
          expect(val).to be <= 4
        end
      end
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::IntegerArbitrary.new
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates numbers down to 0 asymptotically" do
      arb = Pbt::Arbitrary::IntegerArbitrary.new
      expect(arb.shrink(100).to_a).to eq [50, 25, 13, 7, 4, 2, 1, 0]
    end

    it "returns an Enumerator that iterates numbers up to 0 asymptotically" do
      arb = Pbt::Arbitrary::IntegerArbitrary.new
      expect(arb.shrink(-100).to_a).to eq [-50, -25, -13, -7, -4, -2, -1, 0]
    end

    describe "target" do
      it "returns an Enumerator that iterates numbers up to target asymptotically" do
        arb = Pbt::Arbitrary::IntegerArbitrary.new
        expect(arb.shrink(100, target: 200).to_a).to eq [150, 175, 187, 193, 196, 198, 199, 200]
      end

      it "returns an Enumerator that iterates numbers down to target asymptotically" do
        arb = Pbt::Arbitrary::IntegerArbitrary.new
        expect(arb.shrink(-100, target: -200).to_a).to eq [-150, -175, -187, -193, -196, -198, -199, -200]
      end
    end
  end
end
