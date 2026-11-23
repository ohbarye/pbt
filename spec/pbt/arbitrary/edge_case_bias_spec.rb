# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Edge-case bias in built-in arbitraries" do
  describe "Pbt.integer" do
    it "reliably surfaces boundary values such as 0 within default num_runs" do
      details = Pbt.check(seed: 42, num_runs: 100, worker: :none) do
        Pbt.property(Pbt.integer) do |n|
          raise "division by zero" if n == 0
        end
      end

      expect(details.failed).to be(true)
      expect(details.counterexample).to eq(0)
    end

    it "covers edge cases while still spreading most draws across the full domain" do
      arb = Pbt.integer(min: -1_000_000, max: 1_000_000)
      stats = Pbt.statistics(arb, num_runs: 500, seed: 123) do |n|
        [-1_000_000, -1, 0, 1, 1_000_000].include?(n) ? :edge : :interior
      end

      expect(stats.counts[:edge]).to be_between(50, 160)
      expect(stats.counts[:interior]).to be > 300

      values = Array.new(500) { arb.generate(Random.new(123)) }
      expect(values).to all(satisfy { |v| arb.cover?(v) })

      # All five boundaries appear over 500 draws with a single RNG.
      rng = Random.new(123)
      draws = Array.new(500) { arb.generate(rng) }
      expect(draws).to include(-1_000_000, -1, 0, 1, 1_000_000)
    end

    it "keeps small domains uniform without extra edge-case skew" do
      arb = Pbt.integer(min: 1, max: 6)
      stats = Pbt.statistics(arb, num_runs: 600, seed: 7)
      (1..6).each do |face|
        expect(stats.counts[face]).to be_between(60, 140)
      end
    end
  end

  describe "Pbt.float" do
    it "surfaces finite float boundaries including 0.0, -0.0, 1.0, -1.0, min, and max" do
      arb = Pbt.float(min: -100.0, max: 100.0)
      rng = Random.new(99)
      draws = Array.new(500) { arb.generate(rng) }

      expect(draws).to all(satisfy { |v| arb.cover?(v) })
      expect(draws).to include(0.0, 1.0, -1.0, -100.0, 100.0)
      expect(draws.any? { |v| v.zero? && (1.0 / v).infinite? == -1 }).to be(true)
    end

    it "does not inject -0.0 into non-negative float domains" do
      arb = Pbt.float(min: 0.0, max: 10.0)
      rng = Random.new(99)
      draws = Array.new(300) { arb.generate(rng) }

      expect(draws.any? { |v| v.zero? && (1.0 / v).infinite? == -1 }).to be(false)
      expect(draws).to include(0.0, 1.0, 10.0)
    end
  end

  describe "Pbt.choose" do
    it "biases large integer and float ranges toward their boundaries while respecting cover?" do
      int_arb = Pbt.choose(0...1000)
      rng = Random.new(11)
      int_draws = Array.new(400) { int_arb.generate(rng) }
      expect(int_draws).to all(satisfy { |v| int_arb.cover?(v) })
      expect(int_draws).to include(0, 1, 999)
      expect(int_draws).not_to include(1000)

      float_arb = Pbt.choose(-10.0...10.0)
      float_draws = Array.new(400) { float_arb.generate(rng) }
      expect(float_draws).to all(satisfy { |v| float_arb.cover?(v) })
      expect(float_draws).to include(-10.0, 0.0, 1.0, -1.0)
      expect(float_draws).not_to include(10.0)
    end
  end

  describe "Pbt.array and Pbt.string with large max lengths" do
    it "reliably generates empty and boundary-length arrays and strings" do
      str_arb = Pbt.string(min: 0, max: 200)
      rng = Random.new(55)
      strings = Array.new(200) { str_arb.generate(rng) }
      expect(strings).to include("")
      expect(strings.any? { |s| s.length == 1 }).to be(true)
      expect(strings.any? { |s| s.length == 200 }).to be(true)
    end
  end
end
