# frozen_string_literal: true

RSpec.describe "Weighted generators" do
  [:none, :ractor].each do |worker|
    it "shrinks the failing branch with #{worker} and reports plain values" do
      result = Pbt.check(seed: 42, num_runs: 20, worker: worker) do
        Pbt.property(Pbt.frequency([1, Pbt.integer(min: 1, max: 100)], [1, Pbt.constant(nil)])) do |value|
          raise "positive" if value.is_a?(Integer) && value >= 5
        end
      end
      expect(result.failed).to be(true)
      expect(result.counterexample).to eq(5)
      expect(result.num_shrinks).to be > 0
      expect(result.failures.map(&:val)).to all(be_a(Integer))
    end
  end

  it "shrinks shared weighted generators in a tuple independently" do
    arb = Pbt.frequency([1, Pbt.integer(min: 0, max: 100)], [1, Pbt.constant(nil)])
    result = Pbt.check(seed: 10, num_runs: 100) do
      Pbt.property(arb, arb) do |a, b|
        raise "sum" if a.is_a?(Integer) && b.is_a?(Integer) && a + b >= 10
      end
    end
    expect(result.failed).to be(true)
    expect(result.counterexample).to eq([0, 14])
    expect(result.num_shrinks).to be > 0
  end
  it "supports custom generators with only generate and shrink" do
    custom = Object.new
    def custom.generate(_rng)
      10
    end

    def custom.shrink(value)
      ((value > 0) ? [0] : []).each
    end

    [custom, Pbt.frequency([1, custom])].each do |arb|
      result = Pbt.check(num_runs: 1) do
        Pbt.property(arb) { |_value| raise "failure" }
      end
      expect(result.counterexample).to eq(0)
      expect(result.num_shrinks).to eq(1)
    end
  end
end
