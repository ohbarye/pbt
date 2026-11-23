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

    it "raises EmptyDomainError for an impossible range" do
      arb = Pbt::Arbitrary::IntegerArbitrary.new(1, 0)

      expect { arb.generate(Random.new) }
        .to raise_error(Pbt::Arbitrary::EmptyDomainError)
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt.integer
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "yields binary-search candidates from target up to current - 1 for positive values" do
      arb = Pbt.integer
      expect(arb.shrink(100).to_a).to eq [0, 50, 75, 87, 93, 96, 98, 99]
    end

    it "yields binary-search candidates from target down to current + 1 for negative values" do
      arb = Pbt.integer
      expect(arb.shrink(-100).to_a).to eq [0, -50, -75, -87, -93, -96, -98, -99]
    end

    it "converges to the exact failure threshold under greedy shrinking" do
      [10, 11, 12, 13, 19].each do |threshold|
        details = Pbt.check(seed: 1, num_runs: 100) do
          Pbt.property(Pbt.integer(min: 1, max: 50)) do |n|
            raise "threshold" if n >= threshold
          end
        end

        expect(details.failed).to be(true)
        expect(details.counterexample).to eq(threshold)
      end
    end

    describe "target" do
      it "yields binary-search candidates toward a higher target" do
        arb = Pbt.integer
        expect(arb.shrink(100, target: 200).to_a).to eq [200, 150, 125, 113, 107, 104, 102, 101]
      end

      it "yields binary-search candidates toward a lower target" do
        arb = Pbt.integer
        expect(arb.shrink(-100, target: -200).to_a).to eq [-200, -150, -125, -113, -107, -104, -102, -101]
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
