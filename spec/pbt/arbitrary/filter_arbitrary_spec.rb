# frozen_string_literal: true

RSpec.describe Pbt::Arbitrary::FilterArbitrary do
  describe "#initialize" do
    it "builds a FilterArbitrary" do
      arb = Pbt.integer.filter { |n| n % 2 == 0 }
      expect(arb).to be_a(Pbt::Arbitrary::FilterArbitrary)
    end

    it "rejects missing block" do
      expect { Pbt.integer.filter }.to raise_error(ArgumentError, /block/)
    end

    it "rejects non-positive or non-integer max_attempts" do
      [0, -1, 1.5, nil, "10"].each do |invalid|
        expect { Pbt.integer.filter(max_attempts: invalid) { true } }.to raise_error(ArgumentError, /max_attempts/)
      end
    end
  end

  describe "#generate" do
    it "generates filtered values of given arbitrary" do
      val = Pbt.integer.filter { |n| n % 2 == 0 }.generate(Random.new)
      expect(val).to be_even
    end

    it "raises FilterExhaustedError after max_attempts for unsatisfiable predicates" do
      attempts = 0
      arb = Pbt.integer(min: 0, max: 10).filter(max_attempts: 5) do |_n|
        attempts += 1
        false
      end

      expect { arb.generate(Random.new(1)) }.to raise_error(Pbt::Arbitrary::FilterExhaustedError, /5 attempts/)
      expect(attempts).to eq(5)
    end
  end

  describe "#sample" do
    it "raises FilterExhaustedError after max_attempts for unsatisfiable predicates" do
      attempts = 0
      arb = Pbt.one_of(Pbt.integer(min: 0, max: 10)).filter(max_attempts: 4) do |_n|
        attempts += 1
        false
      end

      expect { arb.sample(Random.new(1)) }.to raise_error(Pbt::Arbitrary::FilterExhaustedError, /4 attempts/)
      expect(attempts).to eq(4)
    end

    it "propagates FilterExhaustedError out of Pbt.check" do
      expect {
        Pbt.check(num_runs: 1, worker: :none) do
          Pbt.property(Pbt.constant(1).filter(max_attempts: 3) { false }) {}
        end
      }.to raise_error(Pbt::Arbitrary::FilterExhaustedError, /3 attempts/)
    end
  end

  describe "#shrink" do
    it "returns an Enumerator" do
      arb = Pbt.integer.filter { |n| n % 2 == 0 }
      val = arb.generate(Random.new)
      expect(arb.shrink(val)).to be_a(Enumerator)
    end

    it "returns an Enumerator that iterates filtered values" do
      arb = Pbt.integer.filter { |n| n % 2 == 0 }
      expect(arb.shrink(50).to_a).to eq [4, 2, 0]
    end

    context "when current value and target is same" do
      it "returns an empty Enumerator" do
        arb = Pbt.integer.filter { |n| n % 2 == 0 }
        expect(arb.shrink(0).to_a).to eq []
      end
    end
  end
end
