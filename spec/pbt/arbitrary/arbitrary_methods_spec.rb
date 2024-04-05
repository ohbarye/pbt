# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ArbitraryMethods do
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
        expect(arb.shrink("z").to_a).to eq ["=", "\u001F", "\u0010", "\b", "\u0004", "\u0002", "\u0001", "\u0000"]
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
        expect(arb.shrink(-123.123456).to_a).to eq [-61.561728, -30.780864, -15.390432, -7.695216, -3.847608, -1.923804, -0.961902, 0.0]
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
        expect(arb.shrink(Set.new([10, 20, -44])).to_a).to eq [
          Set.new([20, -44]),
          Set.new([-44]),
          Set.new([])
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

      it "returns an Enumerator that iterates hash shrinking towards empty" do
        arb = Pbt.hash(Pbt.symbol, Pbt.integer)
        expect(arb.shrink({a: 10, b: 20, c: -1}).to_a).to eq [
          {b: 20, c: -1},
          {c: -1},
          {}
        ]
      end
    end
  end
end
