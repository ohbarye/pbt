# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pbt::Arbitrary::FloatArbitrary do
  describe "#initialize" do
    it "rejects non-finite or non-Integer/Float bounds" do
      expect { Pbt.float(min: Float::NAN) }.to raise_error(ArgumentError)
      expect { Pbt.float(max: Float::INFINITY) }.to raise_error(ArgumentError)
      expect { Pbt.float(min: "0.0") }.to raise_error(ArgumentError)
      expect { Pbt.float(min: Complex(1, 2)) }.to raise_error(ArgumentError)
      expect { Pbt.float(min: Rational(1, 3)) }.to raise_error(ArgumentError)
    end
  end

  describe "#generate" do
    it "generates finite floats within explicit min/max bounds" do
      arb = Pbt.float(min: -2.5, max: 3.5)
      values = Array.new(200) { arb.generate(Random.new) }
      expect(values).to all(be_a(Float).and(be_finite))
      expect(values).to all(be_between(-2.5, 3.5))
    end

    it "raises EmptyDomainError when min > max or no representable Float exists in [min, max]" do
      expect { Pbt.float(min: 5.0, max: 1.0).generate(Random.new(1)) }.to raise_error(Pbt::Arbitrary::EmptyDomainError)

      unrepresentable = (2**53) + 1
      expect { Pbt.float(min: unrepresentable, max: unrepresentable).generate(Random.new(1)) }
        .to raise_error(Pbt::Arbitrary::EmptyDomainError)
      expect { Pbt.float(min: unrepresentable, max: unrepresentable - 1).generate(Random.new(1)) }
        .to raise_error(Pbt::Arbitrary::EmptyDomainError)
      expect(Pbt.float(min: unrepresentable, max: unrepresentable).cover?(unrepresentable.to_f)).to be(false)

      tight = Pbt.float(min: unrepresentable, max: unrepresentable + 1)
      val = tight.generate(Random.new(1))
      expect(val).to eq((unrepresentable + 1).to_f)
      expect(tight.cover?(val)).to be(true)
    end

    it "handles one-sided bounds beyond the default range including very large magnitudes" do
      rng = Random.new(7)
      high = Pbt.float(min: 2_000_000.0)
      low = Pbt.float(max: -2_000_000.0)
      huge = Pbt.float(min: 1e30)

      high_vals = Array.new(50) { high.generate(rng) }
      low_vals = Array.new(50) { low.generate(rng) }
      huge_vals = Array.new(50) { huge.generate(rng) }

      expect(high_vals).to all(be >= 2_000_000.0)
      expect(low_vals).to all(be <= -2_000_000.0)
      expect(huge_vals).to all(be >= 1e30)
      expect(huge_vals.uniq.size).to be > 1
      expect(high.cover?(2_500_000.0)).to be(true)
      expect(low.cover?(-2_500_000.0)).to be(true)
      expect(Pbt.float.cover?(5_000_000.0)).to be(true)
    end

    it "supports opt-in allow_nan and allow_infinity respecting finite bounds" do
      rng = Random.new(42)
      nan_values = Array.new(300) { Pbt.float(min: 0.0, max: 1.0, allow_nan: true).generate(rng) }
      expect(nan_values.any?(&:nan?)).to be(true)
      expect(nan_values.reject(&:nan?)).to all(be_between(0.0, 1.0))

      inf_values = Array.new(400) { Pbt.float(min: 0.0, allow_infinity: true).generate(rng) }
      expect(inf_values).to include(Float::INFINITY)
      expect(inf_values).not_to include(-Float::INFINITY)
    end
  end

  describe "#cover?" do
    it "checks finite bounds, NaN, and Infinity accurately" do
      bounded = Pbt.float(min: 0.0, max: 10.0)
      expect(bounded.cover?(0.0)).to be(true)
      expect(bounded.cover?(5.5)).to be(true)
      expect(bounded.cover?(10.0)).to be(true)
      expect(bounded.cover?(-0.1)).to be(false)
      expect(bounded.cover?(10.1)).to be(false)
      expect(bounded.cover?(5)).to be(false)
      expect(bounded.cover?(Float::NAN)).to be(false)
      expect(bounded.cover?(Float::INFINITY)).to be(false)

      special = Pbt.float(min: 0.0, allow_nan: true, allow_infinity: true)
      expect(special.cover?(Float::NAN)).to be(true)
      expect(special.cover?(Float::INFINITY)).to be(true)
      expect(special.cover?(-Float::INFINITY)).to be(false)
    end
  end

  describe "#shrink" do
    it "shrinks fractional floats smoothly toward 0.0 or the nearest bound" do
      arb = Pbt.float(min: 0.0, max: 1.0)
      shrunk = arb.shrink(0.5).to_a
      expect(shrunk.first).to eq(0.0)
      expect(shrunk).to include(0.25, 0.375)
      expect(shrunk).to all(be_between(0.0, 0.5))

      details = Pbt.check(seed: 1, num_runs: 50, worker: :none) do
        Pbt.property(Pbt.float(min: 0.0, max: 10.0)) do |x|
          raise "too big" if x >= 2.5
        end
      end
      expect(details.failed).to be(true)
      expect(details.counterexample).to be_within(0.01).of(2.5)
    end

    it "shrinks NaN and Infinity to finite values" do
      arb = Pbt.float(allow_nan: true, allow_infinity: true)
      expect(arb.shrink(Float::NAN).to_a).to eq([0.0])
      expect(arb.shrink(Float::INFINITY).to_a).to include(0.0)
    end
  end
end
