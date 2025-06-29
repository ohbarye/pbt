# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::IntegerArbitrary do
  describe "#generate" do
    it "generates an integer" do
      val = Pbt.integer.generate(Random.new)
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
      arb = Pbt.integer
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates numbers down to 0 asymptotically" do
      arb = Pbt.integer
      expect(arb.shrink(100).to_a).to eq [50, 25, 13, 7, 4, 2, 1, 0]
    end

    it "returns an Enumerator that iterates numbers up to 0 asymptotically" do
      arb = Pbt.integer
      expect(arb.shrink(-100).to_a).to eq [-50, -25, -13, -7, -4, -2, -1, 0]
    end

    describe "target" do
      it "returns an Enumerator that iterates numbers up to target asymptotically" do
        arb = Pbt.integer
        expect(arb.shrink(100, target: 200).to_a).to eq [150, 175, 187, 193, 196, 198, 199, 200]
      end

      it "returns an Enumerator that iterates numbers down to target asymptotically" do
        arb = Pbt.integer
        expect(arb.shrink(-100, target: -200).to_a).to eq [-150, -175, -187, -193, -196, -198, -199, -200]
      end

      context "when current value and target is same" do
        it "returns an empty Enumerator" do
          arb = Pbt.integer
          expect(arb.shrink(0, target: 0).to_a).to eq []
        end
      end
    end

    describe "with min/max constraints" do
      it "shrinks values within the specified range" do
        arb = Pbt::Arbitrary::IntegerArbitrary.new(25, 65)
        shrunk_values = arb.shrink(50).to_a

        expect(shrunk_values).to all(be >= 25)
        expect(shrunk_values).to all(be <= 65)
      end

      it "shrinks from max value respecting the min constraint" do
        arb = Pbt::Arbitrary::IntegerArbitrary.new(25, 65)
        shrunk_values = arb.shrink(65).to_a

        expect(shrunk_values).to all(be >= 25)
        expect(shrunk_values).to all(be <= 65)
        expect(shrunk_values.last).to be >= 25
      end

      it "shrinks from min value respecting the min constraint" do
        arb = Pbt::Arbitrary::IntegerArbitrary.new(25, 65)
        shrunk_values = arb.shrink(25).to_a

        expect(shrunk_values).to be_empty
      end

      it "shrinks negative range values within constraints" do
        arb = Pbt::Arbitrary::IntegerArbitrary.new(-50, -10)
        shrunk_values = arb.shrink(-20).to_a

        expect(shrunk_values).to all(be >= -50)
        expect(shrunk_values).to all(be <= -10)
      end
    end
  end
end
