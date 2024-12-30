require "pbt"
require "benchmark/ips"

# With this seed, the 4th case fails and it shrinks happens 13 times.
seed = 17243810592888013452170775373100387856

def task(x) = (x > 100) ? raise : nil

Benchmark.ips do |x|
  x.report("ractor") do
    Pbt.assert(worker: :ractor, seed:, num_runs: 100) do
      Pbt.property(Pbt.integer) do |x|
        task(x)
      end
    end
  rescue Pbt::PropertyFailure
    # noop
  end

  x.report("none") do
    Pbt.assert(worker: :none, seed:, num_runs: 100) do
      Pbt.property(Pbt.integer) do |x|
        task(x)
      end
    end
  rescue Pbt::PropertyFailure
    # noop
  end
end
