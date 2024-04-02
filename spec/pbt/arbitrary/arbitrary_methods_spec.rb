# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::ArbitraryMethods do
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
end
