# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::FilterArbitrary do
  describe "#initialize" do
    it do
      arb = Pbt.integer.filter { |n| n % 2 == 0 }
      expect(arb).to be_a(Pbt::Arbitrary::FilterArbitrary)
    end
  end

  describe "#generate" do
    it "generates filtered values of given arbitrary" do
      val = Pbt.integer.filter { |n| n % 2 == 0 }.generate(Random.new)
      expect(val).to be_even
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt.integer.filter { |n| n % 2 == 0 }
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates filtered values" do
      arb = Pbt.integer.filter { |n| n % 2 == 0 }
      expect(arb.shrink(50).to_a).to eq [4, 2, 0]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt.integer.filter { |n| n % 2 == 0 }
        expect(arb.shrink(0).to_a).to eq []
      end
    end
  end
end
