# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "Pbt.statistics" do
  it "counts generated values and exposes replay information" do
    result = Pbt.statistics(Pbt.constant(:ok), num_runs: 4, seed: 12)
    expect(result.counts).to eq({ok: 4})
    expect(result.percentages).to eq({ok: 100.0})
    expect(result.num_runs).to eq(4)
    expect(result.seed).to eq(12)
  end

  it "classifies values and replays the exact same sample" do
    first = Pbt.statistics(Pbt.integer(min: 0, max: 100), num_runs: 100, seed: 17) { |n| n.even? ? :even : :odd }
    replay = Pbt.statistics(Pbt.integer(min: 0, max: 100), num_runs: 100, seed: first.seed) { |n| n.even? ? :even : :odd }
    expect(first.counts).to eq(replay.counts)
    expect(first.counts.values.sum).to eq(100)
    expect(first.counts.keys).to contain_exactly(:even, :odd)
    expect(first.percentages.values.sum).to eq(100.0)
  end

  it "returns empty statistics for zero runs without generating values" do
    arb = Object.new
    def arb.generate(_rng)
      raise "must not generate"
    end
    result = Pbt.statistics(arb, num_runs: 0)
    expect(result.counts).to eq({})
    expect(result.percentages).to eq({})
  end

  [-1, 1.5, nil, "2", true].each do |runs|
    it "rejects invalid run count #{runs.inspect}" do
      expect { Pbt.statistics(Pbt.integer, num_runs: runs) }.to raise_error(ArgumentError)
    end
  end

  it "supports custom generators and keeps successive calls independent" do
    arb = Object.new
    def arb.generate(rng)
      rng.rand(2)
    end
    first = Pbt.statistics(arb, num_runs: 10, seed: 42)
    first.counts.clear
    expect(Pbt.statistics(arb, num_runs: 10, seed: 42).counts.values.sum).to eq(10)
  end

  it "propagates generator and classifier errors" do
    arb = Object.new
    def arb.generate(_rng)
      raise "generation failed"
    end
    expect { Pbt.statistics(arb) }.to raise_error("generation failed")
    expect { Pbt.statistics(Pbt.constant(1)) { raise "classification failed" } }.to raise_error("classification failed")
  end
  it "retains an automatically chosen seed for replay" do
    first = Pbt.statistics(Pbt.integer(min: 0, max: 100), num_runs: 20)
    expect(first.seed).to be_a(Integer)
    expect(Pbt.statistics(Pbt.integer(min: 0, max: 100), num_runs: 20, seed: first.seed).counts).to eq(first.counts)
  end

  it "classifies once per generated value and returns unrounded percentages" do
    calls = 0
    result = Pbt.statistics(Pbt.constant(:value), num_runs: 3) do |_value|
      calls += 1
      (calls == 1) ? :first : :rest
    end
    expect(calls).to eq(3)
    expect(result.counts).to eq({first: 1, rest: 2})
    expect(result.percentages).to eq({first: 100.0 / 3, rest: 200.0 / 3})
    Pbt.statistics(Pbt.constant(:value), num_runs: 0) { raise "must not classify" }
  end
  it "does not change the global random sequence" do
    script = <<~RUBY
      require "pbt"
      srand(1234)
      expected = rand
      srand(1234)
      Pbt.statistics(Pbt.integer, num_runs: 5, seed: 99)
      abort "global random sequence changed" unless rand == expected
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "-e", script)
    expect(status.success?).to be(true), output
  end
end
