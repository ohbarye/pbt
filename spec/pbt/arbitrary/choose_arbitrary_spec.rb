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

    it "never returns the excluded upper bound for adjacent exclusive Float ranges" do
      arb = Pbt.choose(1.0...1.0.next_float)
      rng = Random.new(0)
      values = Array.new(50) { arb.generate(rng) }

      expect(values).to all(eq(1.0))
      expect(values).to all(satisfy { |v| arb.cover?(v) })
    end

    it "preserves value types for non-Float Numeric ranges such as Rational" do
      arb = Pbt.choose(Rational(1)..Rational(3))
      rng = Random.new(1)
      values = Array.new(30) { arb.generate(rng) }

      expect(values).to all(be_a(Rational))
      expect(values).to all(satisfy { |v| arb.cover?(v) })
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::ChooseArbitrary.new(1..10)
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates binary-search integers towards the min" do
      arb = Pbt::Arbitrary::ChooseArbitrary.new(-2..10)
      expect(arb.shrink(10).to_a).to eq [-2, 4, 7, 8, 9]
    end

    it "shrinks Float ranges smoothly toward min and respects exclusive end" do
      inclusive = Pbt.choose(0.0..1.0)
      shrunk = inclusive.shrink(0.5).to_a
      expect(shrunk.first).to eq(0.0)
      expect(shrunk).to include(0.25, 0.375)
      expect(shrunk).to all(be_between(0.0, 0.5))

      exclusive = Pbt.choose(1...5)
      expect(exclusive.shrink(4).to_a).to eq [1, 2, 3]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ChooseArbitrary.new(-2..10)
        expect(arb.shrink(-2).to_a).to eq []
      end
    end
  end
end
