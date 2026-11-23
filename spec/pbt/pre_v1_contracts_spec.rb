# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pre-v1.0.0 quality contracts" do
  describe "runner option validation" do
    it "rejects unknown option keys before generation" do
      expect {
        Pbt.check(num_run: 5) { Pbt.property(Pbt.constant(1)) {} }
      }.to raise_error(Pbt::InvalidConfiguration, /unknown option.*:num_run/)
    end

    it "rejects invalid num_runs, worker, and seed before generation" do
      [0, -1, 1.5, "5", nil].each do |bad_num_runs|
        expect {
          Pbt.check(num_runs: bad_num_runs) { Pbt.property(Pbt.constant(1)) {} }
        }.to raise_error(Pbt::InvalidConfiguration, /num_runs/)
      end

      [:thread, :typo, nil, "none"].each do |bad_worker|
        expect {
          Pbt.check(num_runs: 1, worker: bad_worker) { Pbt.property(Pbt.constant(1)) {} }
        }.to raise_error(Pbt::InvalidConfiguration, /worker/)
      end

      ["42", 1.5, nil].each do |bad_seed|
        expect {
          Pbt.check(num_runs: 1, seed: bad_seed) { Pbt.property(Pbt.constant(1)) {} }
        }.to raise_error(Pbt::InvalidConfiguration, /seed/)
      end
    end

    it "rejects missing blocks and invalid arbitraries eagerly" do
      expect { Pbt.check }.to raise_error(ArgumentError, /requires a block/)
      expect { Pbt.assert }.to raise_error(ArgumentError, /requires a block/)
      expect { Pbt.property(Pbt.integer) }.to raise_error(ArgumentError, /requires a predicate block/)
      expect { Pbt.property { nil } }.to raise_error(ArgumentError, /at least one arbitrary/)
      expect { Pbt.property(123) { |_| } }.to raise_error(ArgumentError, /generate and shrink/)
      expect { Pbt.property(a: 123) { |a:| a } }.to raise_error(ArgumentError, /generate and shrink/)
      expect { Pbt.array(Pbt.integer, min: -1) }.to raise_error(ArgumentError, /min must be zero or positive/)
      expect { Pbt.hash(Pbt.symbol) }.to raise_error(ArgumentError, /Pbt\.hash expects/)
    end
  end

  describe "counterexample inspection formatting" do
    it "formats empty strings, strings vs integers, and nil unambiguously using inspect" do
      expect {
        Pbt.assert(num_runs: 1, seed: 1, verbose: true) do
          Pbt.property(Pbt.constant("")) { |_| raise "empty" }
        end
      }.to raise_error(Pbt::PropertyFailure) do |err|
        expect(err.message).to include('counterexample: ""')
        expect(err.message).to include('- ""')
        expect(err.message).to include("\x1b[31m\u00D7\x1b[0m \"\"")
      end

      expect {
        Pbt.assert(num_runs: 1, seed: 1) do
          Pbt.property(Pbt.constant("1")) { |_| raise "string one" }
        end
      }.to raise_error(Pbt::PropertyFailure, /counterexample: "1"/)

      expect {
        Pbt.assert(num_runs: 1, seed: 1) do
          Pbt.property(Pbt.nil) { |_| raise "got nil" }
        end
      }.to raise_error(Pbt::PropertyFailure, /counterexample: nil/)
    end
  end

  describe "shrinking termination guarantees" do
    it "terminates cleanly when a non-injective MapArbitrary unmapper maps back to the same value" do
      arb = Pbt.integer(min: 0, max: 10).map(->(_) { 0 }, ->(_) { 10 })
      calls = 0

      details = Pbt.check(num_runs: 1, seed: 1, worker: :none) do
        Pbt.property(arb) do |_|
          calls += 1
          raise "always fails"
        end
      end

      expect(details.failed).to be(true)
      expect(details.counterexample).to eq(0)
      expect(calls).to eq(1)
    end

    it "terminates cleanly on cyclic or non-decreasing custom bare shrinkers" do
      cyclic_arb = Object.new
      def cyclic_arb.generate(_rng = Random.new)
        1
      end

      def cyclic_arb.shrink(current)
        [current + 1, 1].each
      end

      details = Pbt.check(num_runs: 1, seed: 1, worker: :none) do
        Pbt.property(cyclic_arb) { |_| raise "boom" }
      end

      expect(details.failed).to be(true)
      expect(details.num_shrinks).to be <= 10_000
    end
  end

  describe "ractor generation error ordering" do
    it "preserves an earlier property failure when a later case in the batch raises during generation" do
      arb = Pbt.integer(min: 0, max: 1).flat_map do |n|
        n.zero? ? Pbt.constant(:first) : Pbt.constant_from
      end

      # Find a seed where draw 0 is 0 (:first) and draw 1 is 1 (EmptyDomainError).
      seed = (0..100).find do |candidate_seed|
        rng = Random.new(candidate_seed)
        first = begin
          arb.generate(rng)
        rescue Pbt::Arbitrary::EmptyDomainError
          :err
        end
        second = begin
          arb.generate(rng)
        rescue Pbt::Arbitrary::EmptyDomainError
          :err
        end
        first == :first && second == :err
      end
      expect(seed).not_to be_nil

      [:none, :ractor].each do |worker|
        details = Pbt.check(seed: seed, num_runs: 2, worker: worker) do
          Pbt.property(arb) { |v| raise "failed on #{v}" }
        end
        expect(details.failed).to be(true)
        expect(details.counterexample).to eq(:first)
      end
    end
  end

  describe "public API surface cleanup" do
    it "does not expose Pbt.toss as a public method" do
      expect(Pbt.respond_to?(:toss)).to be(false)
    end

    it "keeps internal mapper constants private on Pbt::Arbitrary" do
      expect { Pbt::Arbitrary::CHAR_MAPPER }.to raise_error(NameError)
      expect { Pbt::Arbitrary::SET_MAPPER }.to raise_error(NameError)
    end

    it "raises EmptyDomainError for Pbt.frequency with empty or zero-only weights" do
      expect { Pbt.frequency }.to raise_error(Pbt::Arbitrary::EmptyDomainError)
      expect { Pbt.frequency([0, Pbt.constant(1)]) }.to raise_error(Pbt::Arbitrary::EmptyDomainError)
    end
  end
end
