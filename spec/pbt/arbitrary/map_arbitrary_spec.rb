# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::MapArbitrary do
  describe "#initialize / Arbitrary#map" do
    it "accepts explicit mapper and unmapper" do
      arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
      expect(arb).to be_a(Pbt::Arbitrary::MapArbitrary)
      expect(arb.contextual?).to be(false)
    end

    it "accepts a single callable mapper without unmapper" do
      arb = Pbt.integer.map(->(n) { n.to_s })
      expect(arb).to be_a(Pbt::Arbitrary::MapArbitrary)
      expect(arb.contextual?).to be(true)
    end

    it "accepts a block without unmapper" do
      arb = Pbt.integer.map { |n| n.to_s }
      expect(arb).to be_a(Pbt::Arbitrary::MapArbitrary)
      expect(arb.contextual?).to be(true)
    end

    it "rejects missing, ambiguous, or non-callable arguments" do
      expect { Pbt.integer.map }.to raise_error(ArgumentError)
      expect { Pbt.integer.map(->(n) { n }) { |n| n } }.to raise_error(ArgumentError)
      expect { Pbt.integer.map(123) }.to raise_error(ArgumentError)
      expect { Pbt.integer.map(->(n) { n }, 123) }.to raise_error(ArgumentError)
    end
  end

  describe "#generate" do
    it "generates mapped values with explicit unmapper" do
      val = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i }).generate(Random.new)
      expect(val).to be_a(String)
    end

    it "generates mapped values with block form" do
      val = Pbt.integer(min: 1, max: 10).map { |n| n * 2 }.generate(Random.new)
      expect(val).to be_a(Integer)
      expect(val).to be_even
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates binary-search values when unmapper is given" do
      arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
      expect(arb.shrink("50").to_a).to eq ["0", "25", "37", "43", "46", "48", "49"]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt.integer.map(->(n) { n.to_s }, ->(n) { n.to_i })
        expect(arb.shrink("0").to_a).to eq []
      end
    end

    context "when unmapper is omitted" do
      it "returns an empty Enumerator for bare shrink" do
        arb = Pbt.integer.map { |n| n.to_s }
        expect(arb.shrink("50").to_a).to eq []
      end
    end
  end

  describe "#sample and contextual shrinking without unmapper" do
    it "shrinks non-invertible block mappings via sample provenance" do
      arb = Pbt.integer(min: 0, max: 100).map { |n| {value: n, doubled: n * 2} }
      rng = double("rng")
      expect(rng).to receive(:rand).with(0..100).and_return(10)

      sample = arb.sample(rng)
      expect(sample.value).to eq({value: 10, doubled: 20})
      expect(sample.shrink.map(&:value)).to eq([
        {value: 0, doubled: 0},
        {value: 5, doubled: 10},
        {value: 7, doubled: 14},
        {value: 8, doubled: 16},
        {value: 9, doubled: 18}
      ])
    end

    it "shrinks chained block mappings inside array, tuple, fixed_hash, and filter" do
      arb = Pbt.fixed_hash(
        label: Pbt.integer(min: 0, max: 10).map { |n| n + 1 }.map { |n| "v#{n}" }.filter { |s| s != "v2" }
      )
      rng = double("rng")
      expect(rng).to receive(:rand).with(0..10).and_return(4)

      sample = arb.sample(rng)
      expect(sample.value).to eq({label: "v5"})
      expect(sample.shrink.map(&:value)).to eq([{label: "v1"}, {label: "v3"}, {label: "v4"}])
    end

    it "supports non-Proc callable objects in sample and Pbt.check" do
      callable = Class.new do
        def call(n)
          "num:#{n}"
        end
      end.new

      arb = Pbt.integer(min: 0, max: 100).map(callable)
      result = Pbt.check(seed: 42, num_runs: 50, worker: :none) do
        Pbt.property(arb) do |label|
          raise "too big" if label.delete_prefix("num:").to_i >= 10
        end
      end

      expect(result.failed).to be(true)
      expect(result.counterexample).to start_with("num:")
      expect(result.num_shrinks).to be > 0
    end

    it "shrinks failures in Pbt.check under both :none and :ractor workers" do
      baseline = Pbt.check(seed: 42, num_runs: 50, worker: :none) do
        Pbt.property(Pbt.integer(min: 0, max: 100)) do |n|
          raise "too large" if n >= 10
        end
      end

      [:none, :ractor].each do |worker|
        arb = Pbt.integer(min: 0, max: 100).map { |n| "item-#{n}" }
        result = Pbt.check(seed: 42, num_runs: 50, worker: worker) do
          Pbt.property(arb) do |label|
            n = label.delete_prefix("item-").to_i
            raise "too large" if n >= 10
          end
        end

        expect(result.failed).to be(true)
        expect(result.counterexample).to eq("item-#{baseline.counterexample}")
        expect(result.num_shrinks).to eq(baseline.num_shrinks)
        expect(result.num_shrinks).to be > 0
      end
    end
  end
end
