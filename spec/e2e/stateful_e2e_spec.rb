# frozen_string_literal: true

RSpec.describe Pbt do
  describe ".assert with .stateful" do
    it "runs a stateful property through the existing runner" do
      Pbt.assert(seed: 2, num_runs: 1) do
        Pbt.stateful(model: PassingCounterModel.new, sut: -> { Object.new }, max_steps: 5)
      end
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
        expect(e.message).to match(/Shrunk (\d+) time\(s\)/)
        expect(e.message[/Shrunk (\d+) time\(s\)/, 1].to_i).to be > 0
      end
    end
  end

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

    def verify!(before_state:, after_state:, args: _, result:, sut: _)
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
end
