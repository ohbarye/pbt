# frozen_string_literal: true

RSpec.describe "Arbitrary#cover?" do
  let(:unknown_arb) do
    Class.new(Pbt::Arbitrary::Arbitrary) do
      def generate(_rng = Random.new)
        :custom
      end

      def shrink(_current)
        [].each
      end
    end.new
  end

  let(:duck_typed_arb) do
    obj = Object.new
    def obj.generate(_rng = Random.new)
      :duck
    end

    def obj.shrink(_current)
      [].each
    end
    obj
  end

  let(:non_boolean_cover_arb) do
    Class.new(Pbt::Arbitrary::Arbitrary) do
      def generate(_rng = Random.new) = 1
      def shrink(_current) = [].each
      def cover?(_value) = :yes
    end.new
  end

  describe "base Arbitrary" do
    it "returns nil by default" do
      expect(unknown_arb.cover?(123)).to be_nil
      expect(unknown_arb.cover?(:custom)).to be_nil
    end

    it "normalizes non-boolean custom cover? results to nil consistently across composites" do
      expect(Pbt.tuple(non_boolean_cover_arb).cover?([1])).to be_nil
      expect(Pbt.array(non_boolean_cover_arb, min: 1, max: 2).cover?([1])).to be_nil
      expect(Pbt.one_of(non_boolean_cover_arb).cover?(1)).to be_nil
      expect(Pbt.frequency([1, non_boolean_cover_arb]).cover?(1)).to be_nil
    end
  end

  describe "IntegerArbitrary" do
    it "checks type and inclusive bounds" do
      arb = Pbt.integer(min: -2, max: 5)
      expect(arb.cover?(-2)).to be(true)
      expect(arb.cover?(0)).to be(true)
      expect(arb.cover?(5)).to be(true)
      expect(arb.cover?(-3)).to be(false)
      expect(arb.cover?(6)).to be(false)
      expect(arb.cover?(1.5)).to be(false)
      expect(arb.cover?("1")).to be(false)
    end

    it "checks nat with explicit max" do
      arb = Pbt.nat(max: 100)
      expect(arb.cover?(0)).to be(true)
      expect(arb.cover?(100)).to be(true)
      expect(arb.cover?(-1)).to be(false)
      expect(arb.cover?(101)).to be(false)
    end
  end

  describe "ChooseArbitrary" do
    it "checks integer ranges strictly including exclusive end" do
      inclusive = Pbt.choose(1..5)
      expect(inclusive.cover?(1)).to be(true)
      expect(inclusive.cover?(5)).to be(true)
      expect(inclusive.cover?(0)).to be(false)
      expect(inclusive.cover?(6)).to be(false)
      expect(inclusive.cover?(2.5)).to be(false)
      expect(inclusive.cover?("3")).to be(false)

      exclusive = Pbt.choose(1...5)
      expect(exclusive.cover?(4)).to be(true)
      expect(exclusive.cover?(5)).to be(false)
    end

    it "supports float ranges strictly for finite Float values" do
      arb = Pbt.choose(1.0..2.0)
      expect(arb.cover?(1.5)).to be(true)
      expect(arb.cover?(1)).to be(false)
      expect(arb.cover?(Rational(3, 2))).to be(false)
      expect(arb.cover?(Float::NAN)).to be(false)
      expect(arb.cover?("1.5")).to be(false)
    end

    it "rejects unbounded ranges and raises EmptyDomainError on empty ranges during generate" do
      expect(Pbt.choose(0..).cover?(0)).to be(false)
      expect(Pbt.choose(..10).cover?(5)).to be(false)
      expect(Pbt.choose(2..1).cover?(1)).to be(false)
      expect { Pbt.choose(2..1).generate(Random.new) }.to raise_error(Pbt::Arbitrary::EmptyDomainError)
      expect { Pbt.choose(1...1).generate(Random.new) }.to raise_error(Pbt::Arbitrary::EmptyDomainError)
    end
  end

  describe "ConstantArbitrary and ConstantFromArbitrary" do
    it "checks type-preserving equality and handles NaN for ConstantArbitrary" do
      expect(Pbt.constant(42).cover?(42)).to be(true)
      expect(Pbt.constant(42).cover?(42.0)).to be(false)
      expect(Pbt.constant(42).cover?(43)).to be(false)
      expect(Pbt.nil.cover?(nil)).to be(true)
      expect(Pbt.nil.cover?(false)).to be(false)

      nan_arb = Pbt.constant(Float::NAN)
      expect(nan_arb.cover?(nan_arb.generate)).to be(true)
    end

    it "checks type-preserving membership for ConstantFromArbitrary" do
      arb = Pbt.constant_from(:a, 1, nil)
      expect(arb.cover?(:a)).to be(true)
      expect(arb.cover?(1)).to be(true)
      expect(arb.cover?(1.0)).to be(false)
      expect(arb.cover?(nil)).to be(true)
      expect(arb.cover?(:c)).to be(false)

      nan_arb = Pbt.constant_from(Float::NAN)
      expect(nan_arb.cover?(nan_arb.generate)).to be(true)
    end
  end

  describe "OneOfArbitrary and FrequencyArbitrary (3-valued OR)" do
    it "returns true if any branch covers, false if all reject, nil if unknown remains" do
      one_of_known = Pbt.one_of(Pbt.integer(min: 1, max: 3), Pbt.constant(:x))
      expect(one_of_known.cover?(2)).to be(true)
      expect(one_of_known.cover?(:x)).to be(true)
      expect(one_of_known.cover?(99)).to be(false)

      one_of_mixed = Pbt.one_of(Pbt.integer(min: 1, max: 3), unknown_arb)
      expect(one_of_mixed.cover?(2)).to be(true)
      expect(one_of_mixed.cover?(:other)).to be_nil

      one_of_duck = Pbt.one_of(Pbt.integer(min: 1, max: 3), duck_typed_arb)
      expect(one_of_duck.cover?(2)).to be(true)
      expect(one_of_duck.cover?(:other)).to be_nil

      freq_known = Pbt.frequency([0, Pbt.constant(:ignored)], [2, Pbt.integer(min: 1, max: 3)], [1, Pbt.constant(:ok)])
      expect(freq_known.cover?(2)).to be(true)
      expect(freq_known.cover?(:ok)).to be(true)
      expect(freq_known.cover?(:ignored)).to be(false)
      expect(freq_known.cover?(99)).to be(false)

      freq_mixed = Pbt.frequency([1, Pbt.integer(min: 1, max: 3)], [1, unknown_arb])
      expect(freq_mixed.cover?(2)).to be(true)
      expect(freq_mixed.cover?(:other)).to be_nil
    end
  end

  describe "TupleArbitrary, ArrayArbitrary, and FixedHashArbitrary (3-valued AND)" do
    it "aggregates TupleArbitrary elements with 3-valued AND" do
      arb = Pbt.tuple(Pbt.integer(min: 1, max: 5), Pbt.constant(:ok))
      expect(arb.cover?([3, :ok])).to be(true)
      expect(arb.cover?([0, :ok])).to be(false)
      expect(arb.cover?([3])).to be(false)
      expect(arb.cover?("not an array")).to be(false)

      mixed = Pbt.tuple(Pbt.integer(min: 1, max: 5), unknown_arb)
      expect(mixed.cover?([3, :anything])).to be_nil
      expect(mixed.cover?([0, :anything])).to be(false)
    end

    it "aggregates ArrayArbitrary length and elements with 3-valued AND" do
      arb = Pbt.array(Pbt.integer(min: 0, max: 5), min: 1, max: 3)
      expect(arb.cover?([0, 5])).to be(true)
      expect(arb.cover?([])).to be(false)
      expect(arb.cover?([1, 2, 3, 4])).to be(false)
      expect(arb.cover?([1, 6])).to be(false)
      expect(arb.cover?("not an array")).to be(false)

      mixed = Pbt.array(unknown_arb, min: 0, max: 2)
      expect(mixed.cover?([])).to be(true)
      expect(mixed.cover?([:a])).to be_nil
      expect(mixed.cover?([:a, :b, :c])).to be(false)
    end

    it "checks FixedHashArbitrary keys regardless of insertion order" do
      arb = Pbt.fixed_hash(x: Pbt.integer(min: 1, max: 5), y: Pbt.constant(:ok))
      expect(arb.cover?({x: 3, y: :ok})).to be(true)
      expect(arb.cover?({y: :ok, x: 3})).to be(true)
      expect(arb.cover?({x: 3})).to be(false)
      expect(arb.cover?({x: 3, y: :ok, z: 1})).to be(false)
      expect(arb.cover?({x: 0, y: :ok})).to be(false)
      expect(arb.cover?([3, :ok])).to be(false)

      mixed = Pbt.fixed_hash(x: Pbt.integer(min: 1, max: 5), y: unknown_arb)
      expect(mixed.cover?({x: 3, y: :anything})).to be_nil
      expect(mixed.cover?({x: 0, y: :anything})).to be(false)
    end
  end

  describe "FilterArbitrary" do
    it "combines base cover? and refinement predicate safely" do
      arb = Pbt.integer(min: 0, max: 10).filter(&:even?)
      expect(arb.cover?(4)).to be(true)
      expect(arb.cover?(3)).to be(false)
      expect(arb.cover?(12)).to be(false)
      expect(arb.cover?("not an int")).to be(false)

      mixed = unknown_arb.filter { |v| v == :custom }
      expect(mixed.cover?(:custom)).to be_nil
      expect(mixed.cover?(:other)).to be(false)

      raising = unknown_arb.filter { |v| v.even? }
      expect(raising.cover?("not numeric")).to be_nil
    end
  end

  describe "MapArbitrary and derived built-ins" do
    it "returns nil when unmapper is omitted" do
      arb = Pbt.integer(min: 0, max: 10).map { |n| n * 2 }
      expect(arb.cover?(4)).to be_nil
      expect(arb.cover?("anything")).to be_nil
    end

    it "is conservative (returns true on verified preimage, nil otherwise) for user maps" do
      arb = Pbt.integer(min: 0, max: 10).map(->(n) { n.to_s }, ->(s) { s.to_i })
      expect(arb.cover?("5")).to be(true)
      expect(arb.cover?("99")).to be_nil
      expect(arb.cover?("abc")).to be_nil
      expect(arb.cover?(5)).to be_nil

      # Non-invertible shrink unmapper must never falsely reject a valid generated value.
      shifted = Pbt.integer(min: 0, max: 10).map(->(n) { (n + 1).to_s }, ->(s) { s.to_i })
      expect(shifted.cover?("3")).to be_nil

      abs_arb = Pbt.integer(min: -10, max: -1).map(->(n) { n.abs }, ->(n) { n })
      expect(abs_arb.cover?(5)).to be_nil
    end

    it "rescues unmapper errors and returns nil" do
      arb = Pbt.integer(min: 0, max: 10).map(->(n) { n.to_s }, ->(s) { Integer(s) })
      expect(arb.cover?("abc")).to be_nil
    end

    it "works soundly for FloatArbitrary" do
      expect(Pbt.float.cover?(0.0)).to be(true)
      expect(Pbt.float.cover?(1.5)).to be(true)
      expect(Pbt.float.cover?(1_000_001.0)).to be(true)
      expect(Pbt.float(min: 0.0, max: 10.0).cover?(10.5)).to be(false)
      expect(Pbt.float.cover?(Float::NAN)).to be(false)
      expect(Pbt.float.cover?(Float::INFINITY)).to be(false)
      expect(Pbt.float.cover?("1.5")).to be(false)
    end

    it "never rejects values generated by set or hash even when deduplication shrinks size below min" do
      set_arb = Pbt.set(Pbt.constant(1), min: 2, max: 2)
      generated_set = set_arb.generate(Random.new(1))
      expect(generated_set).to eq(Set[1])
      expect(set_arb.cover?(generated_set)).not_to be(false)

      hash_arb = Pbt.hash(Pbt.constant(:k), Pbt.constant(1), min: 2, max: 2)
      generated_hash = hash_arb.generate(Random.new(1))
      expect(generated_hash).to eq({k: 1})
      expect(hash_arb.cover?(generated_hash)).not_to be(false)

      expect(Pbt.set(Pbt.integer(min: 1, max: 5)).cover?(Set[1, 2])).to be(true)
      expect(Pbt.hash(Pbt.symbol, Pbt.integer(min: 1, max: 5)).cover?({a: 1})).to be(true)
    end

    it "works accurately for bijective derived built-in arbitraries" do
      expect(Pbt.char.cover?("a")).to be(true)
      expect(Pbt.char.cover?("ab")).to be(false)

      expect(Pbt.symbol.cover?(:abc)).to be(true)
      expect(Pbt.symbol.cover?("abc")).to be(false)
      expect(Pbt.symbol.cover?(:ABC)).to be(false)

      expect(Pbt.hexa_string(min: 1, max: 3).cover?("a1f")).to be(true)
      expect(Pbt.hexa_string(min: 1, max: 3).cover?("xyz")).to be(false)
      expect(Pbt.hexa_string(min: 1, max: 3).cover?("")).to be(false)

      base_date = Date.new(2024, 4, 6)
      date_arb = Pbt.date(base_date: base_date, past_offset_days: -5, future_offset_days: 5)
      expect(date_arb.cover?(Date.new(2024, 4, 8))).to be(true)
      expect(date_arb.cover?(Date.new(2024, 5, 1))).to be(false)

      base_time = Time.new(2024, 1, 2, 3, 4, 5)
      time_arb = Pbt.time(base_time: base_time, past_offset_seconds: -10, future_offset_seconds: 10)
      expect(time_arb.cover?(Time.new(2024, 1, 2, 3, 4, 10))).to be(true)
      expect(time_arb.cover?(Time.new(2024, 1, 2, 3, 5, 0))).to be(false)
    end
  end
end
