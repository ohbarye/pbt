# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::OneOfArbitrary do
  describe "#initialize" do
    it "rejects empty arguments" do
      expect { Pbt.one_of }.to raise_error(ArgumentError)
    end

    it "rejects non-arbitrary choices" do
      expect { Pbt.one_of(:a, :b) }.to raise_error(ArgumentError)
      expect { Pbt.one_of(Pbt.integer, 42) }.to raise_error(ArgumentError)
      expect { Pbt.one_of(nil) }.to raise_error(ArgumentError)
    end
  end

  describe "#generate" do
    it "selects uniformly among arbitraries and replays with the same seed" do
      arb = Pbt.one_of(Pbt.integer(min: 10, max: 20), Pbt.constant(nil))
      first = Random.new(17)
      second = Random.new(17)
      values = Array.new(100) { arb.generate(first) }

      expect(values).to eq(Array.new(100) { arb.generate(second) })
      expect(values.compact).to all(be_between(10, 20))
      expect(values).to include(nil)
      expect(values.compact).not_to be_empty
    end

    it "selects branch index using rng.rand(size)" do
      arb = Pbt.one_of(Pbt.constant(:a), Pbt.constant(:b), Pbt.constant(:c))
      (0...3).each do |idx|
        rng = double("rng")
        expect(rng).to receive(:rand).with(3).and_return(idx)
        expect(arb.generate(rng)).to eq([:a, :b, :c][idx])
      end
    end
  end

  describe "#shrink" do
    it "does not guess the source arbitrary of a bare value" do
      expect(Pbt.one_of(Pbt.integer, Pbt.constant(nil)).shrink(10).to_a).to eq([])
    end
  end

  describe "#sample and contextual shrinking" do
    it "retains independent shrinking for equal values from different branches" do
      left = Pbt.integer(min: 0, max: 10)
      right = Pbt.integer(min: 10, max: 20)
      arb = Pbt.one_of(left, right)

      rng = double("rng")
      expect(rng).to receive(:rand).with(2).ordered.and_return(0)
      expect(rng).to receive(:rand).with(0..10).ordered.and_return(10)
      expect(rng).to receive(:rand).with(2).ordered.and_return(1)
      expect(rng).to receive(:rand).with(10..20).ordered.and_return(10)

      first = arb.sample(rng)
      second = arb.sample(rng)
      expect(first.value).to eq(10)
      expect(second.value).to eq(10)
      expect(first.shrink.map(&:value)).to eq([5, 3, 2, 1, 0])
      expect(second.shrink.to_a).to eq([])
    end

    it "shrinks within the failing branch under both :none and :ractor workers" do
      [:none, :ractor].each do |worker|
        result = Pbt.check(seed: 42, num_runs: 20, worker: worker) do
          Pbt.property(Pbt.one_of(Pbt.integer(min: 1, max: 100), Pbt.constant(nil))) do |value|
            raise "too big" if value.is_a?(Integer) && value >= 5
          end
        end

        expect(result.failed).to be(true)
        expect(result.counterexample).to eq(5)
        expect(result.num_shrinks).to be > 0
      end
    end

    it "preserves provenance inside array, tuple, fixed_hash, map, and filter" do
      choice = Pbt.one_of(Pbt.integer(min: 0, max: 10))
      array = Pbt.array(choice, min: 0, max: 1)
      mapped = array.map(->(xs) { xs.join(",") }, ->(s) { s.split(",").map(&:to_i) }).filter { |s| !s.empty? }

      rng = double("rng")
      expect(rng).to receive(:rand).with(0..1).ordered.and_return(1)
      expect(rng).to receive(:rand).with(1).ordered.and_return(0)
      expect(rng).to receive(:rand).with(0..10).ordered.and_return(10)

      sample = Pbt.fixed_hash(data: mapped).sample(rng)
      expect(sample.value).to eq({data: "10"})
      expect(sample.shrink.map(&:value)).to eq([
        {data: "5"}, {data: "3"}, {data: "2"}, {data: "1"}, {data: "0"}
      ])
    end
  end
end
