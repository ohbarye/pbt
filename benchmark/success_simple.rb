require "pbt"
require "benchmark/ips"

seed = 17243810592888013452170775373100387856

Benchmark.ips do |x|
  x.report("ractor") do
    Pbt.assert(worker: :ractor, seed:) do
      Pbt.property(Pbt.integer) do |x|
        x + 1
      end
    end
  end

  x.report("process") do
    Pbt.assert(worker: :process, seed:) do
      Pbt.property(Pbt.integer) do |x|
        x + 1
      end
    end
  end

  x.report("thread") do
    Pbt.assert(worker: :thread, seed:) do
      Pbt.property(Pbt.integer) do |x|
        x + 1
      end
    end
  end

  x.report("none") do
    Pbt.assert(worker: :none, seed:) do
      Pbt.property(Pbt.integer) do |x|
        x + 1
      end
    end
  end
end
