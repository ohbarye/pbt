# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ConstantFromArbitrary do
  describe "#initialize" do
    it "raises EmptyDomainError when given no choices" do
      expect { Pbt.constant_from }.to raise_error(Pbt::Arbitrary::EmptyDomainError)
    end
  end

  describe "#generate" do
    it "generates one of the given constant choices" do
      aggregate_failures do
        choices = [:a, 1, "A", 2.0, {foo: :bar}, [1], String]
        arb = Pbt.constant_from(*choices)
        100.times do
          val = arb.generate(Random.new)
          expect(choices).to include(val)
        end
      end
    end

    it "replays deterministically with the same seed" do
      arb = Pbt.constant_from(:a, :b, :c, :d)
      first = Random.new(42)
      second = Random.new(42)

      expect(Array.new(50) { arb.generate(first) }).to eq(Array.new(50) { arb.generate(second) })
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt::Arbitrary::ConstantFromArbitrary.new([1])
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "shrinks towards earlier choices" do
      arb = Pbt::Arbitrary::ConstantFromArbitrary.new([:z, :a, :x, :y, :c, :d])
      expect(arb.shrink(:c).to_a).to eq [:x, :a, :z]
    end

    context "when current value is already the first choice" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ConstantFromArbitrary.new(["A"])
        expect(arb.shrink("A").to_a).to eq []
      end
    end

    context "when current value is not in choices" do
      it "returns an empty Enumerator" do
        arb = Pbt::Arbitrary::ConstantFromArbitrary.new([:a, :b])
        expect(arb.shrink(:unknown).to_a).to eq []
      end
    end

    it "distinguishes numerically equal values of different types via eql?" do
      arb = Pbt.constant_from(1, 1.0)
      expect(arb.shrink(1.0).to_a).to eq [1]
    end
  end

  describe "stateful integration" do
    it "skips commands whose arguments construct an empty constant_from when another command is eligible" do
      result = Pbt.check(seed: 1, num_runs: 5, worker: :none) do
        Pbt.stateful(max_steps: 3) do |m|
          m.initial_state 0
          m.sut { Object.new }

          m.command(:empty) do |c|
            c.arguments { |_state| Pbt.constant_from(*[]) }
            c.run { |_sut, _args| nil }
          end

          m.command(:ok) do |c|
            c.arguments Pbt.constant(1)
            c.next_state { |state, args| state + args }
            c.run { |_sut, args| args }
          end
        end
      end

      expect(result.failed).to be(false)
    end
  end
end
