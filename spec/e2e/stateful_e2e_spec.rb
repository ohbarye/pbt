# frozen_string_literal: true

RSpec.describe Pbt do
  describe ".assert with .stateful" do
    it "runs a stateful property through the existing runner" do
      Pbt.assert(seed: 2, num_runs: 1) do
        Pbt.stateful(model: PassingCounterModel.new, sut: -> { Object.new }, max_steps: 5)
      end
    end

    it "runs state-dependent arguments and arg-aware applicability through the existing runner" do
      Pbt.assert(seed: 2, num_runs: 1) do
        Pbt.stateful(model: StatefulWithdrawModel.new, sut: -> { StatefulBankAccount.new(3) }, max_steps: 3)
      end
    end

    it "defaults to :none for stateful properties even when global worker is :ractor" do
      original_worker = Pbt.configuration.worker
      Pbt.configure { |config| config.worker = :ractor }

      Pbt.assert(seed: 2, num_runs: 1) do
        Pbt.stateful(model: PassingCounterModel.new, sut: -> { Object.new }, max_steps: 1)
      end
    ensure
      Pbt.configure { |config| config.worker = original_worker }
    end

    it "rejects ractor worker with a clear configuration error" do
      expect {
        Pbt.check(seed: 1, num_runs: 1, worker: :ractor) do
          Pbt.stateful(model: PassingCounterModel.new, sut: -> { Object.new }, max_steps: 1)
        end
      }.to raise_error(Pbt::InvalidConfiguration, /Pbt\.stateful .*worker: :none/)
    end

    it "reports stateful step context and shrink details on failure" do
      expect {
        Pbt.assert(seed: 1, num_runs: 1, verbose: false) do
          Pbt.stateful(model: AlwaysFailingCounterModel.new, sut: -> { Object.new }, max_steps: 5)
        end
      }.to raise_error(Pbt::PropertyFailure) do |e|
        expect(e.message).to include("Property failed after 1 test(s)")
        expect(e.message).to include("counterexample:")
        expect(e.message).to include("command=:boom")
        expect(e.message).to include("Got RuntimeError: stateful step 0 (boom): boom at state=0")
        expect(e.message).to include("[args=nil]")
        expect(e.message).to match(/Shrunk (\d+) time\(s\)/)
        expect(e.message[/Shrunk (\d+) time\(s\)/, 1].to_i).to be > 0
      end
    end

    it "shrinks command arguments in the final stateful counterexample" do
      expect {
        Pbt.assert(seed: 1, num_runs: 1, verbose: false) do
          Pbt.stateful(model: PositiveArgFailureModel.new, sut: -> { Object.new }, max_steps: 1)
        end
      }.to raise_error(Pbt::PropertyFailure) do |e|
        expect(e.message).to include("counterexample: [#<Pbt::Stateful::Step command=:positive_only, args=1>]")
        expect(e.message).to include("Got RuntimeError: stateful step 0 (positive_only): positive arg required: 1")
        expect(e.message[/Shrunk (\d+) time\(s\)/, 1].to_i).to be > 0
      end
    end
  end

  # standard:disable Lint/ConstantDefinitionInBlock
  class PassingCounterModel
    def initialize
      @command = PassingCounterCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class PassingCounterCommand
    def name
      :tick
    end

    def arguments
      Pbt.nil
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state + 1
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(before_state:, after_state:, result:, args: _, sut: _)
      raise "unexpected result" unless result.nil?
      raise "state mismatch" unless after_state == before_state + 1
    end
  end

  class AlwaysFailingCounterModel
    def initialize
      @command = AlwaysFailingCounterCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class AlwaysFailingCounterCommand
    def name
      :boom
    end

    def arguments
      Pbt.nil
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state + 1
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(before_state:, **)
      raise "boom at state=#{before_state}"
    end
  end

  class PositiveArgFailureModel
    def initialize
      @command = PositiveArgFailureCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class PositiveArgFailureCommand
    def name
      :positive_only
    end

    def arguments
      Pbt.integer(min: 0, max: 3)
    end

    def applicable?(_state)
      true
    end

    def next_state(state, args)
      state + args
    end

    def run!(_sut, args)
      args
    end

    def verify!(args:, **)
      raise "positive arg required: #{args}" if args.positive?
    end
  end

  class StatefulWithdrawModel
    def initialize
      @command = StatefulWithdrawCommand.new
    end

    def initial_state
      3
    end

    def commands(_state)
      [@command]
    end
  end

  class StatefulWithdrawCommand
    def name
      :withdraw
    end

    def arguments(state)
      Pbt.constant([state, 2].min)
    end

    def applicable?(state, args)
      args.positive? && args <= state
    end

    def next_state(state, args)
      state - args
    end

    def run!(sut, args)
      sut.withdraw(args)
    end

    def verify!(after_state:, sut:, **)
      raise "withdraw mismatch" unless sut.balance == after_state
    end
  end

  class StatefulBankAccount
    attr_reader :balance

    def initialize(balance)
      @balance = balance
    end

    def withdraw(amount)
      @balance -= amount
    end
  end
  # standard:enable Lint/ConstantDefinitionInBlock
end
