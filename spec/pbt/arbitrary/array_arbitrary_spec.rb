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
      expect(arb.shrink([3]).to_a).to eq [[], [0], [1], [2]]
      expect(arb.shrink([2, 0]).to_a).to eq [[], [2], [0], [0, 0], [1, 0]]
      expect(arb.shrink([13, 7, 9]).to_a).to eq [
        [],
        [13],
        [7],
        [9],
        [13, 7],
        [7, 9],
        [13, 9],
        [0, 7, 9],
        [6, 7, 9],
        [9, 7, 9],
        [11, 7, 9],
        [12, 7, 9],
        [13, 0, 9],
        [13, 3, 9],
        [13, 5, 9],
        [13, 6, 9],
        [13, 7, 0],
        [13, 7, 4],
        [13, 7, 6],
        [13, 7, 7],
        [13, 7, 8]
      ]
    end

    it "still shrinks elements when array length is already at min_length" do
      arb = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer(min: 0, max: 100), 1, 1)
      expect(arb.shrink([10]).to_a).to eq [[0], [5], [7], [8], [9]]

      contextual = Pbt.array(Pbt.integer(min: 0, max: 100).map { |n| "item-#{n}" }, min: 1, max: 1)
      result = Pbt.check(seed: 42, num_runs: 10, worker: :none) do
        Pbt.property(contextual) do |items|
          raise "too large" if items.first.delete_prefix("item-").to_i >= 10
        end
      end

      expect(result.failed).to be(true)
      expect(result.num_shrinks).to be > 0
      expect(result.counterexample.first.delete_prefix("item-").to_i).to be < 51
    end

    it "shrinks non-contiguous failing pairs by deleting interior elements" do
      arb = Pbt.array(Pbt.integer(min: 0, max: 10), min: 0, max: 5)
      expect(arb.shrink([1, 0, 0, 2]).to_a).to include([1, 0, 2])
      expect(arb.shrink([1, 0, 2]).to_a).to include([1, 2])

      sample = Pbt::Arbitrary::Sample.array(
        [1, 0, 0, 2].map { |v| Pbt::Arbitrary::Sample.from_value(Pbt.integer(min: 0, max: 10), v) },
        Pbt::Arbitrary::IntegerArbitrary.new(0, 5),
        0
      )
      expect(sample.shrink.map(&:value)).to include([1, 0, 2])

      # End-to-end: [1, 0, 0, 2] where only pairs containing both 1 and 2 fail shrinks to [1, 2].
      result = Pbt.check(seed: 1, num_runs: 100, worker: :none) do
        Pbt.property(Pbt.array(Pbt.integer(min: 0, max: 2), min: 0, max: 5)) do |xs|
          raise "both present" if xs.include?(1) && xs.include?(2)
        end
      end
      expect(result.failed).to be(true)
      expect(result.counterexample.sort).to eq([1, 2])
    end

    it "rejects nil max_length" do
      expect { Pbt.array(Pbt.integer, max: nil) }.to raise_error(ArgumentError)
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ArrayArbitrary.new(Pbt.integer)
        expect(arb.shrink([]).to_a).to eq []
      end
    end
  end
end
