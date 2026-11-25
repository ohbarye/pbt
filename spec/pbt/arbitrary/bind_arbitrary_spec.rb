# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pbt::Arbitrary::BindArbitrary do
  describe "#bind / #flat_map" do
    it "accepts a block or a callable object and aliases flat_map to bind" do
      block_arb = Pbt.integer(min: 1, max: 5).flat_map { |n| Pbt.constant(n * 10) }
      expect(block_arb).to be_a(described_class)
      expect(block_arb.contextual?).to be(true)

      callable = Class.new do
        def call(n)
          Pbt.constant("v#{n}")
        end
      end.new
      callable_arb = Pbt.integer(min: 1, max: 5).bind(callable)
      expect(callable_arb.generate(Random.new(1))).to match(/\Av[1-5]\z/)
    end

    it "rejects missing, ambiguous, or non-callable binders" do
      expect { Pbt.integer.bind }.to raise_error(ArgumentError, /requires a callable/)
      expect { Pbt.integer.bind(->(n) { Pbt.constant(n) }) { |n| Pbt.constant(n) } }.to raise_error(ArgumentError, /not both/)
      expect { Pbt.integer.bind(123) }.to raise_error(ArgumentError, /requires a callable/)
    end

    it "raises ArgumentError when the binder returns a non-arbitrary" do
      bad = Pbt.constant(1).flat_map { |_n| [1, 2, 3] }
      expect { bad.generate(Random.new(1)) }.to raise_error(ArgumentError, /must return an arbitrary/)
      expect { bad.sample(Random.new(1)) }.to raise_error(ArgumentError, /must return an arbitrary/)
    end
  end

  describe "#generate and #sample determinism" do
    it "generates identical values from #generate and #sample for the same RNG seed" do
      arb = Pbt.integer(min: 0, max: 50).flat_map do |min|
        Pbt.integer(min: min, max: 50).map { |max| [min, max] }
      end

      gen_values = Array.new(20) { arb.generate(Random.new(42)) }
      sample_values = Array.new(20) { arb.sample(Random.new(42)).value }
      expect(gen_values).to eq(sample_values)
      expect(gen_values).to all(satisfy { |(min, max)| min <= max })
    end
  end

  describe "#cover? and bare #shrink" do
    it "returns nil for cover? and an empty Enumerator for bare #shrink" do
      arb = Pbt.integer(min: 0, max: 10).flat_map { |n| Pbt.integer(min: n, max: 10) }
      expect(arb.cover?(5)).to be_nil
      expect(arb.shrink(5).to_a).to eq([])
    end
  end

  describe "integrated shrinking in Pbt.check and Pbt.stateful" do
    it "shrinks both outer and inner dependent values to the exact minimal counterexample" do
      arb = Pbt.integer(min: 0, max: 100).flat_map do |min|
        Pbt.integer(min: min, max: 100).map { |max| [min, max] }
      end

      [:none, :ractor].each do |worker|
        details = Pbt.check(seed: 42, num_runs: 100, worker: worker) do
          Pbt.property(arb) do |(min, max)|
            raise "gap too large" if max - min >= 10
          end
        end

        expect(details.failed).to be(true)
        expect(details.counterexample).to eq([0, 10])
        expect(details.num_shrinks).to be > 0
      end
    end

    it "skips EmptyDomainError when outer shrinks to an empty inner domain" do
      empty_domain_hit = false
      arb = Pbt.integer(min: 0, max: 5).flat_map do |n|
        if n == 0
          empty_domain_hit = true
          Pbt.constant_from
        else
          Pbt.integer(min: 1, max: n).map { |x| [n, x] }
        end
      end

      # Start from a non-zero outer value (n = 4) whose shrink candidates start at 0 (EmptyDomainError).
      rng = Random.new(1)
      sample = nil
      loop do
        candidate = arb.sample(rng)
        if candidate.value[0] >= 3
          sample = candidate
          break
        end
      end

      shrunk_values = sample.shrink.map(&:value)
      expect(empty_domain_hit).to be(true)
      expect(shrunk_values).not_to be_empty
      expect(shrunk_values).to all(satisfy { |(n, x)| n >= 1 && x.between?(1, n) })
    end

    it "does not carry over unverifiable bind args when stateful initial_state shrinks" do
      details = Pbt.check(seed: 1, num_runs: 50, worker: :none) do
        Pbt.stateful(min_steps: 1, max_steps: 2) do |m|
          m.initial_state Pbt.integer(min: 0, max: 1)
          m.sut { |init| {state: init} }

          m.command(:check_match) do |c|
            c.arguments { |s| Pbt.constant(s).flat_map { |x| Pbt.constant(x) } }
            c.run do |sut, arg|
              raise "mismatched state=#{sut[:state]} arg=#{arg}" unless sut[:state] == arg
              raise "boom on 1" if arg == 1
            end
          end
        end
      end

      expect(details.failed).to be(true)
      expect(details.counterexample.initial_state).to eq(1)
      expect(details.counterexample.steps.first.args).to eq(1)
      expect(details.error_message).to include("boom on 1")
    end

    it "works inside Pbt.stateful command arguments with shrinking" do
      details = Pbt.check(seed: 42, num_runs: 50) do
        Pbt.stateful(min_steps: 1, max_steps: 4) do |m|
          m.initial_state 0
          m.sut { {max_seen: 0} }

          m.command(:range_op) do |c|
            c.arguments(
              Pbt.integer(min: 0, max: 50).flat_map do |lo|
                Pbt.integer(min: lo, max: 50).map { |hi| {lo: lo, hi: hi} }
              end
            )
            c.run do |sut, args|
              raise "invalid order" if args[:lo] > args[:hi]
              raise "too wide" if args[:hi] - args[:lo] >= 5
              sut[:max_seen] = [sut[:max_seen], args[:hi]].max
            end
          end
        end
      end

      expect(details.failed).to be(true)
      expect(details.counterexample.steps.size).to eq(1)
      expect(details.counterexample.steps.first.args).to eq({lo: 0, hi: 5})
    end
  end
end
