require "pbt"
require "benchmark/ips"

# Read file generated by https://www.lipsum.com/
# 150 paragraphs, 13689 words, 92206 bytes.
def task(str)
  File.read(File.join(__dir__, "example.txt")) + str
end

seed = 17243810592888013452170775373100387856

Benchmark.ips do |x|
  x.report("ractor") do
    Pbt.assert(worker: :ractor, seed:, num_runs: 100) do
      Pbt.property(Pbt.ascii_string) do |str|
        task(str)
      end
    end
  end

  x.report("none") do
    Pbt.assert(worker: :none, seed:, num_runs: 100) do
      Pbt.property(Pbt.ascii_string) do |str|
        task(str)
      end
    end
  end
end
