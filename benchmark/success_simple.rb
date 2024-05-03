require "pbt"
require "benchmark/ips"

seed = 17243810592888013452170775373100387856

def task(x) = x + 1

Benchmark.ips do |x|
  x.report("ractor") do
    Pbt.assert(worker: :ractor, seed:, num_runs: 100) do
      Pbt.property(Pbt.integer) do |x|
        task(x)
      end
    end
  end

  x.report("process") do
    Pbt.assert(worker: :process, seed:, num_runs: 100) do
      Pbt.property(Pbt.integer) do |x|
        task(x)
      end
    end
  end

  x.report("thread") do
    Pbt.assert(worker: :thread, seed:, num_runs: 100) do
      Pbt.property(Pbt.integer) do |x|
        task(x)
      end
    end
  end

  x.report("none") do
    Pbt.assert(worker: :none, seed:, num_runs: 100) do
      Pbt.property(Pbt.integer) do |x|
        task(x)
      end
    end
  end
end
