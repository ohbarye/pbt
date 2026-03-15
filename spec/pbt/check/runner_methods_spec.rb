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
end
