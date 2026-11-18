# frozen_string_literal: true

RSpec.describe "Fiber experiment" do
  it "runs the same cases and preserves failure shrinking and reporting" do
    require_relative "../../benchmark/fiber_experiment"
    [:success, :failure].each do |mode|
      results = [false, true].map do |fiber|
        property = Pbt.property(Pbt.integer(min: 0, max: 100)) do |n|
          raise "threshold" if mode == :failure && n >= 5
        end
        property = FiberExperiment::Property.new(property) if fiber
        Pbt.check(seed: 42, num_runs: 20, worker: :none) { property }
      end
      serial, fiber = results
      [:failed, :num_runs, :num_shrinks, :counterexample, :counterexample_path, :error_message].each do |field|
        expect(fiber.public_send(field)).to eq(serial.public_send(field))
      end
      expect(fiber.failed).to eq(mode == :failure)
      if mode == :success
        expect(fiber.num_runs).to eq(20)
      else
        expect(fiber.counterexample).to eq(5)
        expect(fiber.num_shrinks).to be > 0
      end
    end
  end

  it "executes predicates in a separate fiber without installing a scheduler" do
    require_relative "../../benchmark/fiber_experiment"
    parent = Fiber.current
    scheduler = Fiber.scheduler
    observed = nil
    property = Pbt.property(Pbt.constant(1)) { |_n| observed = Fiber.current }
    result = Pbt.check(num_runs: 1, worker: :none) { FiberExperiment::Property.new(property) }
    expect(result.failed).to be(false)
    expect(observed).not_to equal(parent)
    expect(Fiber.scheduler).to equal(scheduler)
  end
end
