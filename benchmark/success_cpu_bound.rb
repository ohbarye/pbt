require "pbt"
require "benchmark/ips"

# tarai function with
#  (x=10, y=5, z=0) calls 343073 times.
#  (x=10, y=4, z=0) calls 271097 times.
#  (x=9, y=5, z=0) calls 71973 times.
#  (x=9, y=4, z=0) calls 55229 times.
#  (x=8, y=4, z=0) calls 12605 times.
#  (x=8, y=3, z=0) calls 305 times.
def task(x, y, z)
  (x <= y) ? y : task(task(x - 1, y, z),
    task(y - 1, z, x),
    task(z - 1, x, y))
end

a, b, c = [9, 4, 0]

Benchmark.ips do |x|
  x.report("ractor") do
    Pbt.assert(worker: :ractor, num_runs: 100) do
      Pbt.property(Pbt.constant([a, b, c])) do |x, y, z|
        task(x, y, z)
      end
    end
  end

  x.report("process") do
    Pbt.assert(worker: :process, num_runs: 100) do
      Pbt.property(Pbt.constant([a, b, c])) do |x, y, z|
        task(x, y, z)
      end
    end
  end

  x.report("thread") do
    Pbt.assert(worker: :thread, num_runs: 100) do
      Pbt.property(Pbt.constant([a, b, c])) do |x, y, z|
        task(x, y, z)
      end
    end
  end

  x.report("none") do
    Pbt.assert(worker: :none, num_runs: 100) do
      Pbt.property(Pbt.constant([a, b, c])) do |x, y, z|
        task(x, y, z)
      end
    end
  end
end
