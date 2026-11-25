# frozen_string_literal: true

RSpec.describe "Pbt.frequency" do
  it "uses integer weight intervals including boundaries and ignores zero weights" do
    arb = Pbt.frequency([0, Pbt.constant(:never)], [3, Pbt.constant(:a)], [2, Pbt.constant(:b)])
    (0...5).each do |ticket|
      rng = double("rng")
      expect(rng).to receive(:rand).with(5).and_return(ticket)
      expect(arb.generate(rng)).to eq((ticket < 3) ? :a : :b)
    end
  end

  it "generates values rather than generators and replays with the same seed" do
    arb = Pbt.frequency([3, Pbt.integer(min: 10, max: 20)], [1, Pbt.constant(nil)])
    first = Random.new(17)
    second = Random.new(17)
    values = Array.new(100) { arb.generate(first) }
    expect(values).to eq(Array.new(100) { arb.generate(second) })
    expect(values.compact).to all(be_between(10, 20))
    expect(values).to include(nil)
    expect(values.compact).not_to be_empty
    expect(Pbt.frequency([1, Pbt.constant(:ok)]).generate).to eq(:ok)
  end

  [[], [[0, Pbt.constant(1)]], [[-1, Pbt.constant(1)]],
    [[1.5, Pbt.constant(1)]], [["1", Pbt.constant(1)]],
    [[true, Pbt.constant(1)]], [[1, 42]], [[1]], [[1, Pbt.constant(1), 3]], [nil]].each do |pairs|
    it "rejects invalid choices #{pairs.inspect}" do
      expect { Pbt.frequency(*pairs) }.to raise_error(ArgumentError)
    end
  end

  it "does not guess the generator of a bare value" do
    expect(Pbt.frequency([1, Pbt.integer]).shrink(10).to_a).to eq([])
  end

  it "retains independent shrinking for equal values from different branches" do
    left = Pbt.integer(min: 0, max: 10)
    right = Pbt.integer(min: 10, max: 20)
    # Both generate 10, but only the first may shrink toward 0.
    arb = Pbt.frequency([1, left], [1, right])
    rng = double("rng")
    expect(rng).to receive(:rand).with(2).ordered.and_return(0)
    expect(rng).to receive(:rand).with(0..10).ordered.and_return(10)
    expect(rng).to receive(:rand).with(2).ordered.and_return(1)
    expect(rng).to receive(:rand).with(10..20).ordered.and_return(10)
    first = arb.sample(rng)
    second = arb.sample(rng)
    expect(first.value).to eq(10)
    expect(second.value).to eq(10)
    expect(first.shrink.map(&:value)).to eq([0, 5, 7, 8, 9])
    expect(second.shrink.to_a).to eq([])
  end

  it "keeps provenance for shared generators in nested map/filter/hash/tuple/array composition" do
    choice = Pbt.frequency([1, Pbt.integer(min: 1, max: 30)], [1, Pbt.constant(nil)])
    array = Pbt.array(choice, min: 0, max: 4)
    mapped = array.map(->(xs) { {items: xs} }, ->(h) { h.fetch(:items) }).filter { |h| !h[:items].empty? }
    arb = Pbt.tuple(Pbt.fixed_hash(data: mapped), choice)
    sample = arb.sample(Random.new(7))
    # Later generation must not replace the first sample's shrink context.
    100.times { |seed| arb.generate(Random.new(seed)) }
    queue = [sample]
    100.times do
      node = queue.shift
      break unless node
      first, second = node.value
      expect(first[:data][:items]).not_to be_empty
      expect(first[:data][:items].compact).to all(be_between(1, 30))
      expect(second.nil? || (1..30).cover?(second)).to be(true)
      queue.concat(node.shrink.take(10))
    end
  end
  it "propagates actual shrink candidates through array, map, filter and fixed hash" do
    choice = Pbt.frequency([1, Pbt.integer(min: 0, max: 10)])
    array = Pbt.array(choice, min: 0, max: 1)
    mapped = array.map(->(xs) { xs.join(",") }, ->(s) { s.split(",").map(&:to_i) }).filter { |s| !s.empty? }
    rng = double("rng")
    expect(rng).to receive(:rand).with(0..1).ordered.and_return(1)
    expect(rng).to receive(:rand).with(1).ordered.and_return(0)
    expect(rng).to receive(:rand).with(0..10).ordered.and_return(10)
    sample = Pbt.fixed_hash(data: mapped).sample(rng)
    expect(sample.value).to eq({data: "10"})
    expect(sample.shrink.map(&:value)).to eq([
      {data: "0"}, {data: "5"}, {data: "7"}, {data: "8"}, {data: "9"}
    ])
  end
end
