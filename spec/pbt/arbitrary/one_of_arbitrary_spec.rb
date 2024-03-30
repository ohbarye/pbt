# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::OneOfArbitrary do
  describe "#generate" do
    it "generates any integer in given array" do
      aggregate_failures do
        choices = [:a, 1, "A", 2.0, {foo: :bar}, [1], String]
        100.times do
          val = Pbt::Arbitrary::OneOfArbitrary.new(choices).generate(Random.new)
          expect(choices).to include val
        end
      end
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::OneOfArbitrary.new([1])
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates halved integers towards the min" do
      arb = Pbt::Arbitrary::OneOfArbitrary.new([:z, :a, :x, :y, :c, :d])
      expect(arb.shrink(:c).to_a).to eq [:x, :a, :z]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::OneOfArbitrary.new(["A"])
        expect(arb.shrink("A").to_a).to eq []
      end
    end
  end
end
