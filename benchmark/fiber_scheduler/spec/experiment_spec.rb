# frozen_string_literal: true

require "rspec"
require_relative "../experiment"

RSpec.describe SchedulerExperiment do
  it "preserves the seeded inputs and bounds concurrent socket requests" do
    results = [:sequential, :fiber, :scheduler].map do |mode|
      described_class.measure(mode: mode, num_runs: 12, concurrency: 4, delay: 0.01)
    end
    expect(results.map { |result| result.fetch(:values) }.uniq.size).to eq(1)
    expect(results.map { |result| result.fetch(:completed) }).to eq([12, 12, 12])
    expect(results.first(2).map { |result| result.fetch(:max_pending) }).to eq([1, 1])
    expect(results.last.fetch(:max_pending)).to be_between(1, 4)
    expect(Fiber.scheduler).to be_nil
  end

  it "propagates predicate failures and cleans up the server and scheduler" do
    server_threads = Thread.list
    expect {
      described_class.measure(mode: :scheduler, num_runs: 8, concurrency: 4, delay: 0.001) do
        raise "predicate failure"
      end
    }.to raise_error("predicate failure")
    expect(Fiber.scheduler).to be_nil
    expect(Thread.list - server_threads).to be_empty
  end

  it "does not replace a caller's scheduler" do
    Async do
      scheduler = Fiber.scheduler
      expect {
        described_class.measure(mode: :scheduler, num_runs: 1, concurrency: 1, delay: 0)
      }.to raise_error(ArgumentError, /existing scheduler/)
      expect(Fiber.scheduler).to equal(scheduler)
    end.wait
  end
end
