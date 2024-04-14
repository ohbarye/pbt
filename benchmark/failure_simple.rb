require "pbt"
require "benchmark/ips"

# With this seed, the 4th case fails and it shrinks happens 13 times.
seed = 17243810592888013452170775373100387856

Benchmark.ips do |x|
  x.report("ractor") do
    Pbt.assert(worker: :ractor, seed:) do
      Pbt.property(Pbt.integer) do |x|
        raise if x > 100
      end
    end
  rescue Pbt::PropertyFailure
    # noop
  end

  x.report("process") do
    Pbt.assert(worker: :process, seed:) do
      Pbt.property(Pbt.integer) do |x|
        raise if x > 100
      end
    end
  rescue Pbt::PropertyFailure
    # noop
  end

  x.report("thread") do
    Pbt.assert(worker: :thread, seed:) do
      Pbt.property(Pbt.integer) do |x|
        raise if x > 100
      end
    end
  rescue Pbt::PropertyFailure
    # noop
  end

  x.report("none") do
    Pbt.assert(worker: :none, seed:) do
      Pbt.property(Pbt.integer) do |x|
        raise if x > 100
      end
    end
  rescue Pbt::PropertyFailure
    # noop
  end
end
