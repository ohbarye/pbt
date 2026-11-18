# frozen_string_literal: true

require "pbt"
require "delegate"

# Standalone experiment, not a supported worker implementation.
module FiberExperiment
  class Property < SimpleDelegator
    def run(value)
      Fiber.new { __getobj__.run(value) }.resume
    end
  end

  def self.check(fiber:, num_runs:, &predicate)
    property = Pbt.property(Pbt.integer, &predicate)
    property = Property.new(property) if fiber
    Pbt.check(seed: 42, num_runs: num_runs, worker: :none) { property }
  end

  def self.run(num_runs: 100)
    workloads = {
      cpu: ->(n) { 1000.times { n * n } },
      blocking_sleep: ->(_n) { sleep(0.001) }
    }
    puts "Ruby #{RUBY_VERSION}; #{num_runs} cases; seed 42; no scheduler installed"
    workloads.each do |name, predicate|
      [false, true].each do |fiber|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = check(fiber: fiber, num_runs: num_runs, &predicate)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        raise "incorrect execution" if result.failed || result.num_runs != num_runs

        puts format("%-26s %.6f seconds", "#{name} #{fiber ? "fiber" : "sequential"}", elapsed)
      end
    end
  end
end

FiberExperiment.run(num_runs: Integer(ENV.fetch("NUM_RUNS", "100"))) if $PROGRAM_NAME == __FILE__
