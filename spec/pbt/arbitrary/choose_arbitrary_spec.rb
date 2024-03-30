# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ChooseArbitrary do
  describe "#generate" do
    it "generates an integer" do
      val = Pbt::Arbitrary::ChooseArbitrary.new(1..10).generate(Random.new)
      expect(val).to be_a(Integer)
    end

    it "generates an integer in given range" do
      aggregate_failures do
        100.times do
          val = Pbt::Arbitrary::ChooseArbitrary.new(-1..4).generate(Random.new)
          expect(val).to be >= -1
          expect(val).to be <= 4
        end
      end
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::ChooseArbitrary.new(1..10)
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates halved integers towards the min" do
      arb = Pbt::Arbitrary::ChooseArbitrary.new(-2..10)
      expect(arb.shrink(50).to_a).to eq [24, 11, 5, 2, 0, -1, -2]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ChooseArbitrary.new(-2..10)
        expect(arb.shrink(-2).to_a).to eq []
      end
    end
  end
end
