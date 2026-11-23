# frozen_string_literal: true

RSpec.describe Pbt::Check::RunnerMethods do
  let(:runner_host) do
    Class.new do
      include Pbt::Check::RunnerMethods
    end.new
  end

  describe "#wait_ractor_result" do
    it "uses value when available" do
      ractor = double("ractor")
      allow(ractor).to receive(:respond_to?).with(:value).and_return(true)
      allow(ractor).to receive(:value).and_return(:ok)

      expect(ractor).not_to receive(:take)
      expect(runner_host.send(:wait_ractor_result, ractor)).to eq(:ok)
    end

    it "falls back to take when value is unavailable" do
      ractor = double("ractor")
      allow(ractor).to receive(:respond_to?).with(:value).and_return(false)
      allow(ractor).to receive(:take).and_return(:ok)

      expect(ractor).not_to receive(:value)
      expect(runner_host.send(:wait_ractor_result, ractor)).to eq(:ok)
    end
  end

  describe "#unwrap_ractor_exception" do
    it "returns cause when wrapped error has one" do
      cause = RuntimeError.new("root")
      wrapped = StandardError.new("wrapped")
      allow(wrapped).to receive(:cause).and_return(cause)

      expect(runner_host.send(:unwrap_ractor_exception, wrapped)).to eq(cause)
    end

    it "returns original error when cause is nil" do
      error = StandardError.new("plain")
      allow(error).to receive(:cause).and_return(nil)

      expect(runner_host.send(:unwrap_ractor_exception, error)).to eq(error)
    end
  end

  describe "fatal exception propagation" do
    [
      [SystemExit, -> { exit(1) }],
      [Interrupt, -> { raise Interrupt, "ctrl-c" }],
      [NoMemoryError, -> { raise NoMemoryError, "oom" }]
    ].each do |exception_class, trigger|
      it "re-raises #{exception_class} immediately without shrinking" do
        calls = 0
        expect {
          Pbt.check(num_runs: 5, worker: :none) do
            Pbt.property(Pbt.integer(min: 1, max: 100)) do |_n|
              calls += 1
              trigger.call
            end
          end
        }.to raise_error(exception_class)
        expect(calls).to eq(1)
      end
    end

    it "still catches non-fatal Exception subclasses as property failures" do
      custom_exception = Class.new(Exception) # standard:disable Lint/InheritException
      result = Pbt.check(num_runs: 1, worker: :none) do
        Pbt.property(Pbt.constant(1)) do |_n|
          raise custom_exception, "assertion failed"
        end
      end

      expect(result.failed).to be(true)
      expect(result.error_instance).to be_a(custom_exception)
    end

    it "re-raises fatal exceptions in Pbt.stateful without rewrapping" do
      expect {
        Pbt.check(num_runs: 10, seed: 1, worker: :none) do
          Pbt.stateful(max_steps: 3) do |m|
            m.initial_state 0
            m.sut { Object.new }
            m.command(:interrupt) do |c|
              c.run { |_sut, _args| raise(Interrupt, "ctrl-c") }
            end
          end
        end
      }.to raise_error(Interrupt, "ctrl-c")
    end
  end
end
