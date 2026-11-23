# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ArbitraryMethods do
  describe ".nat" do
    it "generates non-negative integers with default max" do
      aggregate_failures do
        100.times do
          val = Pbt.nat.generate(Random.new)
          expect(val).to be_a(Integer)
          expect(val).to be >= 0
          expect(val).to be <= 1_000_000
        end
      end
    end

    it "rejects nil max" do
      expect { Pbt.nat(max: nil) }.to raise_error(ArgumentError)
    end
  end

  describe ".hexa" do
    it "generates a hexadecimal character" do
      val = Pbt.hexa.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.hexa
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates hexadecimal character shrinking towards lower codepoint" do
        arb = Pbt.hexa
        expect(arb.shrink("f").to_a).to eq ["0", "7", "b", "d", "e"]
      end
    end
  end

  describe ".hexa_string" do
    it "generates a hexa_string" do
      arb = Pbt.hexa_string(min: 1, max: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be_a(String)
          expect(val.size).to be >= 1
          expect(val.size).to be <= 5
        end
      end
    end

    it "is hexa_string" do
      val = Pbt.hexa_string.generate(Random.new)
      val.chars.each do |char|
        expect(Pbt::Arbitrary::HEXA_CHARS).to include(char)
      end
    end
  end

  describe ".char" do
    it "generates a character" do
      val = Pbt.char.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.char
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates characters shrinking towards lower codepoint" do
        arb = Pbt.char
        expect(arb.shrink("z").to_a).to eq ["\u0000", "=", "[", "j", "r", "v", "x", "y"]
      end
    end
  end

  describe ".alphanumeric_char" do
    it "generates a character" do
      val = Pbt.alphanumeric_char.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end

    it "is alphanumeric char" do
      val = Pbt.alphanumeric_char.generate(Random.new)
      expect(Pbt::Arbitrary::ALPHANUMERIC_CHARS).to include(val)
    end
  end

  describe ".alphanumeric_string" do
    it "generates a string" do
      arb = Pbt.alphanumeric_string(min: 1, max: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be_a(String)
          expect(val.size).to be >= 1
          expect(val.size).to be <= 5
        end
      end
    end

    it "is alphanumeric string" do
      val = Pbt.alphanumeric_string.generate(Random.new)
      val.chars.each do |char|
        expect(Pbt::Arbitrary::ALPHANUMERIC_CHARS).to include(char)
      end
    end
  end

  describe ".ascii_char" do
    it "generates a character" do
      val = Pbt.ascii_char.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end

    it "is printable ascii char" do
      val = Pbt.ascii_char.generate(Random.new)
      expect(Pbt::Arbitrary::ASCII_CHARS).to include(val)
    end
  end

  describe ".ascii_string" do
    it "generates a string" do
      arb = Pbt.ascii_string(min: 1, max: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be_a(String)
          expect(val.size).to be >= 1
          expect(val.size).to be <= 5
        end
      end
    end

    it "is ascii string" do
      val = Pbt.ascii_string.generate(Random.new)
      val.chars.each do |char|
        expect(Pbt::Arbitrary::ASCII_CHARS).to include(char)
      end
    end
  end

  describe ".printable_ascii_char" do
    it "generates a character" do
      val = Pbt.printable_ascii_char.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end

    it "is printable ascii char" do
      val = Pbt.printable_ascii_char.generate(Random.new)
      expect(Pbt::Arbitrary::PRINTABLE_ASCII_CHARS).to include(val)
    end
  end

  describe ".printable_ascii_string" do
    it "generates a string" do
      arb = Pbt.printable_ascii_string(min: 1, max: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be_a(String)
          expect(val.size).to be >= 1
          expect(val.size).to be <= 5
        end
      end
    end

    it "is printable_ascii string" do
      val = Pbt.printable_ascii_string.generate(Random.new)
      val.chars.each do |char|
        expect(Pbt::Arbitrary::PRINTABLE_ASCII_CHARS).to include(char)
      end
    end
  end

  describe ".printable_char" do
    it "generates a character" do
      val = Pbt.printable_char.generate(Random.new)
      expect(val).to be_a(String)
      expect(val.size).to eq(1)
    end

    it "is printable char" do
      val = Pbt.printable_char.generate(Random.new)
      expect(Pbt::Arbitrary::PRINTABLE_CHARS).to include(val)
    end
  end

  describe ".printable_string" do
    it "generates a string" do
      arb = Pbt.printable_string(min: 1, max: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be_a(String)
          expect(val.size).to be >= 1
          expect(val.size).to be <= 5
        end
      end
    end

    it "is printable string" do
      val = Pbt.printable_string.generate(Random.new)
      val.chars.each do |char|
        expect(Pbt::Arbitrary::PRINTABLE_CHARS).to include(char)
      end
    end
  end

  describe ".symbol" do
    it "generates a symbol" do
      arb = Pbt.symbol(min: 1, max: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be_a(Symbol)
          expect(val.size).to be >= 1
          expect(val.size).to be <= 5
        end
      end
    end

    it "is symbol using symbol safe character only" do
      val = Pbt.symbol.generate(Random.new)
      val.to_s.chars.each do |char|
        expect(Pbt::Arbitrary::SYMBOL_SAFE_CHARS).to include(char)
      end
    end
  end

  describe ".float" do
    it "is generates float" do
      val = Pbt.float.generate(Random.new)
      expect(val).to be_a(Float)
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.float
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates float shrinking towards zero" do
        arb = Pbt.float
        shrunk = arb.shrink(-123.123456).to_a
        expect(shrunk.first).to eq(0.0)
        expect(shrunk).to all(be_between(-123.123456, 0.0))
        expect(shrunk.size).to be >= 5
      end
    end
  end

  describe ".set" do
    it "generates set" do
      val = Pbt.set(Pbt.integer).generate(Random.new)
      expect(val).to be_a(Set)
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.set(Pbt.integer)
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates set shrinking towards empty" do
        arb = Pbt.set(Pbt.integer)
        expect(arb.shrink(Set.new([1, 2, -4])).to_a).to eq [
          Set.new([]),
          Set.new([1]),
          Set.new([2]),
          Set.new([-4]),
          Set.new([1, 2]),
          Set.new([2, -4]),
          Set.new([1, -4]),
          Set.new([0, 2, -4]),
          Set.new([1, 0, -4]),
          Set.new([1, -4]),
          Set.new([1, 2, 0]),
          Set.new([1, 2, -2]),
          Set.new([1, 2, -3])
        ]
      end
    end
  end

  describe ".hash" do
    it "generates hash" do
      val = Pbt.hash(Pbt.symbol, Pbt.integer).generate(Random.new)
      expect(val).to be_a(Hash)
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.hash(Pbt.symbol, Pbt.integer)
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates hash with shrunken length or value" do
        arb = Pbt.hash(Pbt.symbol, Pbt.integer)
        expect(arb.shrink({a: 10, b: 20}).to_a).to eq [
          {},
          {a: 10},
          {b: 20},
          {a: 0, b: 20},
          {a: 5, b: 20},
          {a: 7, b: 20},
          {a: 8, b: 20},
          {a: 9, b: 20},
          {a: 20},
          {a: 10, b: 0},
          {a: 10, b: 10},
          {a: 10, b: 15},
          {a: 10, b: 17},
          {a: 10, b: 18},
          {a: 10, b: 19}
        ]
      end
    end
  end

  describe ".boolean" do
    it "generates boolean" do
      val = Pbt.boolean.generate(Random.new)
      expect([true, false]).to include(val)
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.boolean
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates boolean shrinking towards true" do
        arb = Pbt.boolean
        expect(arb.shrink(false).to_a).to eq [true]
        expect(arb.shrink(true).to_a).to eq []
      end
    end
  end

  describe ".nil" do
    it "generates nil" do
      val = Pbt.nil.generate(Random.new)
      expect(val).to eq(nil)
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.nil
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an empty Enumerator" do
        arb = Pbt.nil
        expect(arb.shrink(nil).to_a).to eq []
      end
    end
  end

  describe ".date" do
    it "generates date" do
      val = Pbt.date.generate(Random.new)
      expect(val).to be_a(Date)
    end

    it "generates date within specified offset" do
      base = Date.new(2024, 4, 20)
      arb = Pbt.date(base_date: base, past_offset_days: -10, future_offset_days: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be >= Date.new(2024, 4, 10)
          expect(val).to be <= Date.new(2024, 4, 25)
        end
      end
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.date
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates date shrinking towards base_date" do
        arb = Pbt.date(base_date: Date.new(2024, 4, 6))
        expect(arb.shrink(Date.new(2024, 4, 20)).to_a).to eq [
          Date.new(2024, 4, 6),
          Date.new(2024, 4, 13),
          Date.new(2024, 4, 16),
          Date.new(2024, 4, 18),
          Date.new(2024, 4, 19)
        ]
      end
    end
  end

  describe ".past_date" do
    it "generates past_date" do
      val = Pbt.past_date.generate(Random.new)
      expect(val).to be_a(Date)
    end

    it "generates past_date within specified offset" do
      base = Date.new(2024, 4, 20)
      arb = Pbt.past_date(base_date: base, past_offset_days: -10)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be >= Date.new(2024, 4, 10)
          expect(val).to be <= base
        end
      end
    end
  end

  describe ".future_date" do
    it "generates future_date" do
      val = Pbt.future_date.generate(Random.new)
      expect(val).to be_a(Date)
    end

    it "generates future_date within specified offset" do
      base = Date.new(2024, 4, 20)
      arb = Pbt.future_date(base_date: base, future_offset_days: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be >= base
          expect(val).to be <= Date.new(2024, 4, 25)
        end
      end
    end
  end

  describe ".time" do
    it "generates time" do
      val = Pbt.time.generate(Random.new)
      expect(val).to be_a(Time)
    end

    it "generates time within specified offset" do
      base = Time.new(2024, 1, 2, 3, 4, 5)

      arb = Pbt.time(base_time: base, past_offset_seconds: -86400, future_offset_seconds: 3600)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be >= Time.new(2024, 1, 1, 3, 4, 5)
          expect(val).to be <= Time.new(2024, 1, 2, 4, 4, 5)
        end
      end
    end

    describe "#shrink" do
      it "returns an Enumerator" do
        arb = Pbt.time
        val = arb.generate(Random.new)
        expect(arb.shrink(val)).to be_a(Enumerator)
      end

      it "returns an Enumerator that iterates time shrinking towards base_time" do
        base = Time.new(2024, 1, 2, 3, 4, 5)
        current = Time.new(2024, 2, 1)
        arb = Pbt.time(base_time: base)
        shrunk = arb.shrink(current).to_a

        expect(shrunk.first).to eq(base)
        expect(shrunk.last).to eq(current - 1)
        expect(shrunk).to eq(shrunk.sort)
        expect(shrunk).to all(be >= base)
        expect(shrunk).to all(be < current)
      end
    end
  end

  describe ".past_time" do
    it "generates past_time" do
      val = Pbt.past_time.generate(Random.new)
      expect(val).to be_a(Time)
    end

    it "generates past_time within specified offset" do
      base = Time.new(2024, 1, 2, 3, 4, 5)
      arb = Pbt.past_time(base_time: base, past_offset_seconds: -10)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be >= Time.new(2024, 1, 2, 3, 3, 55)
          expect(val).to be <= base
        end
      end
    end
  end

  describe ".future_time" do
    it "generates future_time" do
      val = Pbt.future_time.generate(Random.new)
      expect(val).to be_a(Time)
    end

    it "generates future_time within specified offset" do
      base = Time.new(2024, 1, 2, 3, 4, 5)
      arb = Pbt.future_time(base_time: base, future_offset_seconds: 5)
      aggregate_failures do
        100.times do
          val = arb.generate(Random.new)
          expect(val).to be >= base
          expect(val).to be <= Time.new(2024, 1, 2, 3, 4, 10)
        end
      end
    end
  end
end
