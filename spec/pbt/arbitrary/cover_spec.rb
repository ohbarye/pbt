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

  describe "base Arbitrary" do
    it "returns nil by default" do
      expect(unknown_arb.cover?(123)).to be_nil
      expect(unknown_arb.cover?(:custom)).to be_nil
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

    it "handles unbounded nat" do
      arb = Pbt.nat
      expect(arb.cover?(0)).to be(true)
      expect(arb.cover?(10**12)).to be(true)
      expect(arb.cover?(-1)).to be(false)
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

    it "supports float ranges" do
      arb = Pbt.choose(0.0..1.0)
      expect(arb.cover?(0.5)).to be(true)
      expect(arb.cover?(1.5)).to be(false)
      expect(arb.cover?("0.5")).to be(false)
    end
  end

  describe "ConstantArbitrary and ConstantFromArbitrary" do
    it "checks equality for ConstantArbitrary" do
      expect(Pbt.constant(42).cover?(42)).to be(true)
      expect(Pbt.constant(42).cover?(43)).to be(false)
      expect(Pbt.nil.cover?(nil)).to be(true)
      expect(Pbt.nil.cover?(false)).to be(false)
    end

    it "checks membership for ConstantFromArbitrary" do
      arb = Pbt.constant_from(:a, :b, nil)
      expect(arb.cover?(:a)).to be(true)
      expect(arb.cover?(nil)).to be(true)
      expect(arb.cover?(:c)).to be(false)
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

    it "validates round-trip and base domain when unmapper is provided" do
      arb = Pbt.integer(min: 0, max: 10).map(->(n) { n.to_s }, ->(s) { s.to_i })
      expect(arb.cover?("5")).to be(true)
      expect(arb.cover?("99")).to be(false)
      expect(arb.cover?("abc")).to be(false)
      expect(arb.cover?(5)).to be(false)
    end

    it "rescues unmapper errors and returns nil" do
      arb = Pbt.integer(min: 0, max: 10).map(->(n) { n.to_s }, ->(s) { Integer(s) })
      expect(arb.cover?("abc")).to be_nil
    end

    it "works accurately for derived built-in arbitraries" do
      expect(Pbt.float.cover?(1.5)).to be(true)
      expect(Pbt.float.cover?(0.0)).to be(true)
      expect(Pbt.float.cover?(Float::NAN)).to be(false)
      expect(Pbt.float.cover?(Float::INFINITY)).to be(false)
      expect(Pbt.float.cover?("1.5")).to be(false)

      expect(Pbt.char.cover?("a")).to be(true)
      expect(Pbt.char.cover?("ab")).to be(false)

      expect(Pbt.symbol.cover?(:abc)).to be(true)
      expect(Pbt.symbol.cover?("abc")).to be(false)
      expect(Pbt.symbol.cover?(:ABC)).to be(false)

      expect(Pbt.hexa_string(min: 1, max: 3).cover?("a1f")).to be(true)
      expect(Pbt.hexa_string(min: 1, max: 3).cover?("xyz")).to be(false)
      expect(Pbt.hexa_string(min: 1, max: 3).cover?("")).to be(false)

      expect(Pbt.set(Pbt.integer(min: 1, max: 5)).cover?(Set[1, 2])).to be(true)
      expect(Pbt.set(Pbt.integer(min: 1, max: 5)).cover?(Set[1, 9])).to be(false)
      expect(Pbt.set(Pbt.integer(min: 1, max: 5)).cover?([1, 2])).to be(false)

      expect(Pbt.hash(Pbt.symbol, Pbt.integer(min: 1, max: 5)).cover?({a: 1})).to be(true)
      expect(Pbt.hash(Pbt.symbol, Pbt.integer(min: 1, max: 5)).cover?({a: 9})).to be(false)
      expect(Pbt.hash(Pbt.symbol, Pbt.integer(min: 1, max: 5)).cover?([[:a, 1]])).to be(false)

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
