# frozen_string_literal: true

RSpec.describe "generate with default rng" do
  describe "primitives" do
    it "generates an integer without rng" do
      val = Pbt.integer.generate
      expect(val).to be_a(Integer)
    end

    it "generates a boolean without rng" do
      val = Pbt.boolean.generate
      expect([true, false]).to include(val)
    end

    it "generates a constant without rng" do
      val = Pbt.constant(42).generate
      expect(val).to eq(42)
    end

    it "generates a symbol without rng" do
      val = Pbt.symbol.generate
      expect(val).to be_a(Symbol)
    end
  end

  describe "composites" do
    it "generates an array without rng" do
      val = Pbt.array(Pbt.integer).generate
      expect(val).to be_a(Array)
      val.each { |v| expect(v).to be_a(Integer) }
    end

    it "generates a tuple without rng" do
      val = Pbt.tuple(Pbt.integer, Pbt.symbol).generate
      expect(val).to be_a(Array)
      expect(val.size).to eq(2)
      expect(val[0]).to be_a(Integer)
      expect(val[1]).to be_a(Symbol)
    end

    it "generates a fixed_hash without rng" do
      val = Pbt.fixed_hash(x: Pbt.integer, y: Pbt.symbol).generate
      expect(val).to be_a(Hash)
      expect(val.keys).to eq([:x, :y])
      expect(val[:x]).to be_a(Integer)
      expect(val[:y]).to be_a(Symbol)
    end

    it "generates one_of without rng" do
      val = Pbt.one_of(:a, :b, :c).generate
      expect([:a, :b, :c]).to include(val)
    end
  end

  describe "derived arbitraries" do
    it "generates a filtered value without rng" do
      val = Pbt.integer(min: 0, max: 100).filter(&:even?).generate
      expect(val).to be_a(Integer)
      expect(val).to be_even
    end

    it "generates a mapped value without rng" do
      val = Pbt.integer.map(->(n) { n.to_s }, ->(s) { s.to_i }).generate
      expect(val).to be_a(String)
    end
  end

  describe "backward compatibility" do
    it "still accepts rng as argument and uses it deterministically" do
      rng1 = Random.new(42)
      rng2 = Random.new(42)
      val1 = Pbt.integer.generate(rng1)
      val2 = Pbt.integer.generate(rng2)
      expect(val1).to eq(val2)
    end
  end
end
