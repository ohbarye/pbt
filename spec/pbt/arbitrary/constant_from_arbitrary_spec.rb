# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ConstantFromArbitrary do
  describe "#initialize" do
    it "raises EmptyDomainError when given no choices" do
      expect { Pbt.constant_from }.to raise_error(Pbt::Arbitrary::EmptyDomainError)
    end
  end

  describe "#generate" do
    it "generates one of the given constant choices" do
      aggregate_failures do
        choices = [:a, 1, "A", 2.0, {foo: :bar}, [1], String]
        arb = Pbt.constant_from(*choices)
        100.times do
          val = arb.generate(Random.new)
          expect(choices).to include(val)
        end
      end
    end

    it "replays deterministically with the same seed" do
      arb = Pbt.constant_from(:a, :b, :c, :d)
      first = Random.new(42)
      second = Random.new(42)

      expect(Array.new(50) { arb.generate(first) }).to eq(Array.new(50) { arb.generate(second) })
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::ConstantFromArbitrary.new([1])
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "shrinks towards earlier choices" do
      arb = Pbt::Arbitrary::ConstantFromArbitrary.new([:z, :a, :x, :y, :c, :d])
      expect(arb.shrink(:c).to_a).to eq [:x, :a, :z]
    end

    context "when current value is already the first choice" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ConstantFromArbitrary.new(["A"])
        expect(arb.shrink("A").to_a).to eq []
      end
    end

    context "when current value is not in choices" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ConstantFromArbitrary.new([:a, :b])
        expect(arb.shrink(:unknown).to_a).to eq []
      end
    end
  end
end
