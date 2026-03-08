# frozen_string_literal: true

RSpec.describe Pbt do
  describe ".stateful" do
    let(:model) { StackModel.new }

    it "returns a property-like object" do
      property = Pbt.stateful(model:, sut: -> { CorrectStack.new })

      expect(property).to respond_to(:generate)
      expect(property).to respond_to(:shrink)
      expect(property).to respond_to(:run)
    end

    it "raises a clear error when model does not implement required model protocol" do
      expect {
        Pbt.stateful(model: Object.new, sut: -> { Object.new }, max_steps: 1)
      }.to raise_error(Pbt::InvalidConfiguration, /model must respond to initial_state, commands/i)
    end

    it "raises a clear error when max_steps is not an Integer" do
      expect {
        Pbt.stateful(model:, sut: -> { Object.new }, max_steps: "10")
      }.to raise_error(Pbt::InvalidConfiguration, /max_steps must be an Integer/i)
    end

    it "raises a clear error when sut is not callable" do
      expect {
        Pbt.stateful(model:, sut: Object.new, max_steps: 1)
      }.to raise_error(Pbt::InvalidConfiguration, /sut must be callable/i)
    end

    it "raises a clear error when max_steps is negative" do
      expect {
        Pbt.stateful(model:, sut: -> { Object.new }, max_steps: -1)
      }.to raise_error(Pbt::InvalidConfiguration, /max_steps must be non-negative/i)
    end

    it "formats stateful steps with a readable inspect representation" do
      step = Pbt::Stateful::Property::Step.new(command: model.push_command, args: 1)

      expect(step.inspect).to eq("#<Pbt::Stateful::Step command=:push, args=1>")
    end

    it "generates executable command sequences that respect preconditions" do
      property = Pbt.stateful(model:, sut: -> { CorrectStack.new }, max_steps: 10)
      sequence = property.generate(Random.new(1234))

      expect { property.run(sequence) }.not_to raise_error
    end

    it "supports state-dependent command arguments via arguments(state)" do
      model = StateArgumentsWithdrawModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(3) }, max_steps: 1)
      sequence = property.generate(DeterministicRng.new)

      expect(sequence).to eq([
        Pbt::Stateful::Property::Step.new(command: model.command, args: 3)
      ])
      expect { property.run(sequence) }.not_to raise_error
    end

    it "skips state-dependent arguments when a state-only applicable? command is inapplicable during generate" do
      model = ZeroBalanceWithdrawModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(0) }, max_steps: 1)

      expect { property.generate(DeterministicRng.new) }.not_to raise_error
      expect(property.generate(DeterministicRng.new)).to eq([])
    end

    it "raises invalid sequence without materializing state-dependent arguments during run" do
      model = ZeroBalanceWithdrawModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(0) }, max_steps: 1)
      sequence = [{command: model.command, args: 1}]

      expect { property.run(sequence) }
        .to raise_error(RuntimeError, /invalid stateful sequence at step 0: withdraw/)
    end

    it "supports arg-aware applicability via applicable?(state, args)" do
      model = ArgAwareWithdrawModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(3) }, max_steps: 1)
      sequence = property.generate(DeterministicRng.new)

      expect(sequence).to eq([
        Pbt::Stateful::Property::Step.new(command: model.command, args: 2)
      ])
      expect { property.run(sequence) }.not_to raise_error
    end

    it "retries arg generation for arg-aware commands before dropping the command" do
      model = RetriableArgAwareModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(3) }, max_steps: 1)
      sequence = property.generate(SequencedRng.new(
        range_values: {
          [0, 1] => [1],
          [1, 3] => [3, 2]
        }
      ))

      expect(sequence).to eq([
        Pbt::Stateful::Property::Step.new(command: model.command, args: 2)
      ])
    end

    it "supports commands that use both arguments(state) and applicable?(state, args)" do
      model = StrictWithdrawModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(3) }, max_steps: 1)
      sequence = property.generate(DeterministicRng.new)

      expect(sequence).to eq([
        Pbt::Stateful::Property::Step.new(command: model.command, args: 3)
      ])
      expect { property.run(sequence) }.not_to raise_error
    end

    it "raises a clear error when model.commands(state) does not return an Array" do
      property = Pbt.stateful(model: NonArrayCommandsModel.new, sut: -> { Object.new }, max_steps: 1)

      expect { property.generate(Random.new(1)) }
        .to raise_error(Pbt::InvalidConfiguration, /model\.commands\(state\) must return Array.*got Hash.*context=generate/i)
    end

    it "raises a clear error listing missing command protocol methods" do
      property = Pbt.stateful(model: MissingProtocolCommandModel.new, sut: -> { Object.new }, max_steps: 1)

      expect { property.generate(Random.new(1)) }
        .to raise_error(Pbt::InvalidConfiguration, /command protocol mismatch.*MissingProtocolCommand.*name=:broken.*missing: run!, verify!/i)
    end

    it "raises a clear error when arguments has an unsupported signature" do
      property = Pbt.stateful(model: InvalidArgumentsSignatureModel.new, sut: -> { Object.new }, max_steps: 1)

      expect { property.generate(DeterministicRng.new) }
        .to raise_error(Pbt::InvalidConfiguration, /invalid arguments signature; expected arguments or arguments\(state\)/i)
    end

    it "raises a clear error when applicable? has an unsupported signature" do
      property = Pbt.stateful(model: InvalidApplicableSignatureModel.new, sut: -> { Object.new }, max_steps: 1)

      expect { property.generate(DeterministicRng.new) }
        .to raise_error(Pbt::InvalidConfiguration, /invalid applicable\? signature; expected applicable\?\(state\) or applicable\?\(state, args\)/i)
    end

    it "rejects keyword-only arguments signatures during validation" do
      property = Pbt.stateful(model: KeywordArgumentsSignatureModel.new, sut: -> { Object.new }, max_steps: 1)

      expect { property.generate(DeterministicRng.new) }
        .to raise_error(Pbt::InvalidConfiguration, /invalid arguments signature; expected arguments or arguments\(state\)/i)
    end

    it "rejects keyword-only applicable? signatures during validation" do
      property = Pbt.stateful(model: KeywordApplicableSignatureModel.new, sut: -> { Object.new }, max_steps: 1)

      expect { property.generate(DeterministicRng.new) }
        .to raise_error(Pbt::InvalidConfiguration, /invalid applicable\? signature; expected applicable\?\(state\) or applicable\?\(state, args\)/i)
    end

    it "raises a clear error when command.arguments is not an arbitrary-like object" do
      property = Pbt.stateful(model: InvalidArgumentsCommandModel.new, sut: -> { Object.new }, max_steps: 1)

      expect { property.generate(Random.new(1)) }
        .to raise_error(Pbt::InvalidConfiguration, /command arguments protocol mismatch.*InvalidArgumentsCommand.*missing: generate, shrink.*context=generate/i)
    end

    it "raises a clear error for command protocol mismatch in manual sequences during run" do
      property = Pbt.stateful(model:, sut: -> { Object.new }, max_steps: 1)
      sequence = [{command: MissingProtocolCommand.new, args: nil}]

      expect { property.run(sequence) }
        .to raise_error(Pbt::InvalidConfiguration, /command protocol mismatch.*MissingProtocolCommand.*name=:broken.*context=run step 0/i)
    end

    it "raises a clear error for invalid command arguments protocol during shrink" do
      property = Pbt.stateful(model:, sut: -> { Object.new }, max_steps: 1)
      sequence = [{command: InvalidArgumentsCommand.new, args: nil}]

      expect { property.shrink(sequence).to_a }
        .to raise_error(Pbt::InvalidConfiguration, /command arguments protocol mismatch.*InvalidArgumentsCommand.*context=shrink step 0/i)
    end

    it "detects postcondition failures on a buggy SUT" do
      property = Pbt.stateful(model:, sut: -> { BuggyStack.new })

      sequence = [
        {command: model.push_command, args: 1},
        {command: model.push_command, args: 2},
        {command: model.pop_command, args: nil}
      ]

      expect { property.run(sequence) }.to raise_error(RuntimeError, /pop mismatch/)
    end

    it "includes failing step args in wrapped stateful error messages" do
      property = Pbt.stateful(model:, sut: -> { BuggyStack.new })

      sequence = [
        {command: model.push_command, args: 1},
        {command: model.push_command, args: 2},
        {command: model.pop_command, args: nil}
      ]

      expect { property.run(sequence) }
        .to raise_error(RuntimeError, /stateful step 2 \(pop\): .* \[args=nil\]/)
    end

    it "shrinks sequences by trying shorter prefixes first" do
      property = Pbt.stateful(model:, sut: -> { CorrectStack.new })

      sequence = [
        {command: model.push_command, args: 1},
        {command: model.push_command, args: 2},
        {command: model.pop_command, args: nil}
      ]

      expect(property.shrink(sequence).to_a.first(3)).to eq([
        sequence.first(2),
        sequence.first(1),
        []
      ])
    end

    it "shrinks command arguments using each command arbitrary after prefix shrinks" do
      property = Pbt.stateful(model:, sut: -> { CorrectStack.new })

      sequence = [
        {command: model.push_command, args: 3}
      ]

      expect(property.shrink(sequence).to_a).to eq([
        [],
        [{command: model.push_command, args: 2}],
        [{command: model.push_command, args: 1}],
        [{command: model.push_command, args: 0}]
      ])
    end

    it "shrinks state-dependent command arguments with the arbitrary for the current state" do
      model = StateArgumentsWithdrawModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(3) }, max_steps: 1)
      sequence = [{command: model.command, args: 3}]

      expect(property.shrink(sequence).to_a).to eq([
        [],
        [{command: model.command, args: 2}],
        [{command: model.command, args: 1}]
      ])
    end

    it "does not materialize state-dependent arguments for inapplicable steps during shrink" do
      model = ZeroBalanceWithdrawModel.new
      property = Pbt.stateful(model:, sut: -> { BankAccount.new(0) }, max_steps: 1)
      sequence = [{command: model.command, args: 1}]

      expect(property.shrink(sequence).to_a).to eq([
        []
      ])
    end

    it "does not emit duplicate shrink candidates" do
      model = DuplicateShrinkModel.new
      property = Pbt.stateful(model:, sut: -> { Object.new })
      sequence = [{command: model.command, args: 2}]

      expect(property.shrink(sequence).to_a).to eq([
        [],
        [{command: model.command, args: 1}],
        [{command: model.command, args: 0}]
      ])
    end

    it "shrinks in a stable order: prefixes first, then command args from earlier steps" do
      property = Pbt.stateful(model:, sut: -> { CorrectStack.new })
      sequence = [
        {command: model.push_command, args: 1},
        {command: model.push_command, args: 2},
        {command: model.pop_command, args: nil}
      ]

      expect(property.shrink(sequence).to_a).to eq([
        sequence.first(2),
        sequence.first(1),
        [],
        [
          {command: model.push_command, args: 0},
          {command: model.push_command, args: 2},
          {command: model.pop_command, args: nil}
        ],
        [
          {command: model.push_command, args: 1},
          {command: model.push_command, args: 1},
          {command: model.pop_command, args: nil}
        ],
        [
          {command: model.push_command, args: 1},
          {command: model.push_command, args: 0},
          {command: model.pop_command, args: nil}
        ]
      ])
    end
  end

  # standard:disable Lint/ConstantDefinitionInBlock
  class StackModel
    attr_reader :push_command, :pop_command

    def initialize
      @push_command = PushCommand.new
      @pop_command = PopCommand.new
    end

    def initial_state
      []
    end

    def commands(_state)
      [push_command, pop_command]
    end
  end

  class PushCommand
    def name
      :push
    end

    def arguments
      Pbt.integer(min: 0, max: 3)
    end

    def applicable?(_state)
      true
    end

    def next_state(state, args)
      state + [args]
    end

    def run!(sut, args)
      sut.push(args)
    end

    def verify!(after_state:, sut:, before_state: _, args: _, result: _)
      raise "push mismatch" unless sut.snapshot == after_state
    end
  end

  class PopCommand
    def name
      :pop
    end

    def arguments
      Pbt.nil
    end

    def applicable?(state)
      !state.empty?
    end

    def next_state(state, _args)
      state[0...-1]
    end

    def run!(sut, _args)
      sut.pop
    end

    def verify!(before_state:, result:, sut:, after_state: _, args: _)
      expected = before_state.last

      raise "pop mismatch: expected=#{expected.inspect} actual=#{result.inspect}" unless result == expected
      raise "stack mismatch after pop" unless sut.snapshot == before_state[0...-1]
    end
  end

  class CorrectStack
    def initialize
      @values = []
    end

    def push(value)
      @values << value
      nil
    end

    def pop
      @values.pop
    end

    def snapshot
      @values.dup
    end
  end

  class BuggyStack < CorrectStack
    def pop
      @values.shift
    end
  end

  class DuplicateShrinkModel
    attr_reader :command

    def initialize
      @command = DuplicateShrinkCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [command]
    end
  end

  class DuplicateShrinkCommand
    def name
      :dup_shrink
    end

    def arguments
      DuplicateShrinkArbitrary.new
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(**)
      nil
    end
  end

  class DuplicateShrinkArbitrary < Pbt::Arbitrary::Arbitrary
    def generate(rng)
      rng.rand(0..2)
    end

    def shrink(_current)
      Enumerator.new do |y|
        y << 1
        y << 1
        y << 0
      end
    end
  end

  class DeterministicRng
    def rand(value)
      case value
      when Range
        value.end
      when Integer
        0
      else
        raise "unsupported rand argument: #{value.inspect}"
      end
    end
  end

  class SequencedRng
    def initialize(range_values: {})
      @range_values = range_values.transform_values(&:dup)
    end

    def rand(value)
      case value
      when Range
        key = [value.begin, value.end]
        queue = @range_values[key]
        return value.end if queue.nil? || queue.empty?

        queue.shift
      when Integer
        0
      else
        raise "unsupported rand argument: #{value.inspect}"
      end
    end
  end

  class BankAccount
    attr_reader :balance

    def initialize(balance)
      @balance = balance
    end

    def withdraw(amount)
      @balance -= amount
    end
  end

  class StateArgumentsWithdrawModel
    attr_reader :command

    def initialize
      @command = StateArgumentsWithdrawCommand.new
    end

    def initial_state
      3
    end

    def commands(_state)
      [command]
    end
  end

  class StateArgumentsWithdrawCommand
    def name
      :withdraw
    end

    def arguments(state)
      Pbt.integer(min: 1, max: state)
    end

    def applicable?(state)
      state.positive?
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

  class ZeroBalanceWithdrawModel
    attr_reader :command

    def initialize
      @command = NonTotalStateArgumentsWithdrawCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [command]
    end
  end

  class NonTotalStateArgumentsWithdrawCommand
    def name
      :withdraw
    end

    def arguments(state)
      raise "balance must be positive" unless state.positive?

      Pbt.integer(min: 1, max: state)
    end

    def applicable?(state)
      state.positive?
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

  class ArgAwareWithdrawModel
    attr_reader :command

    def initialize
      @command = ArgAwareWithdrawCommand.new
    end

    def initial_state
      3
    end

    def commands(_state)
      [command]
    end
  end

  class ArgAwareWithdrawCommand
    def name
      :withdraw
    end

    def arguments
      Pbt.constant(2)
    end

    def applicable?(state, args)
      args <= state
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

  class RetriableArgAwareModel
    attr_reader :command

    def initialize
      @command = RetriableArgAwareCommand.new
    end

    def initial_state
      3
    end

    def commands(_state)
      [command]
    end
  end

  class RetriableArgAwareCommand
    def name
      :retry_withdraw
    end

    def arguments
      Pbt.integer(min: 1, max: 3)
    end

    def applicable?(state, args)
      args.even? && args <= state
    end

    def next_state(state, args)
      state - args
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(**)
      nil
    end
  end

  class StrictWithdrawModel
    attr_reader :command

    def initialize
      @command = StrictWithdrawCommand.new
    end

    def initial_state
      3
    end

    def commands(_state)
      [command]
    end
  end

  class StrictWithdrawCommand
    def name
      :withdraw_all
    end

    def arguments(state)
      Pbt.constant(state)
    end

    def applicable?(state, args)
      args == state
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

  class NonArrayCommandsModel
    def initial_state
      0
    end

    def commands(_state)
      {oops: :not_an_array}
    end
  end

  class MissingProtocolCommandModel
    def initialize
      @command = MissingProtocolCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class MissingProtocolCommand
    def name
      :broken
    end

    def arguments
      Pbt.nil
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state
    end
  end

  class InvalidArgumentsSignatureModel
    def initialize
      @command = InvalidArgumentsSignatureCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class InvalidArgumentsSignatureCommand
    def name
      :bad_arguments_signature
    end

    def arguments(_state, _extra)
      Pbt.nil
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(**)
      nil
    end
  end

  class InvalidApplicableSignatureModel
    def initialize
      @command = InvalidApplicableSignatureCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class InvalidApplicableSignatureCommand
    def name
      :bad_applicable_signature
    end

    def arguments
      Pbt.nil
    end

    def applicable?(_state, _args, _extra)
      true
    end

    def next_state(state, _args)
      state
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(**)
      nil
    end
  end

  class KeywordArgumentsSignatureModel
    def initialize
      @command = KeywordArgumentsSignatureCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class KeywordArgumentsSignatureCommand
    def name
      :keyword_arguments
    end

    def arguments(state:)
      Pbt.constant(state)
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(**)
      nil
    end
  end

  class KeywordApplicableSignatureModel
    def initialize
      @command = KeywordApplicableSignatureCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class KeywordApplicableSignatureCommand
    def name
      :keyword_applicable
    end

    def arguments
      Pbt.nil
    end

    def applicable?(_state, args:)
      args.nil?
    end

    def next_state(state, _args)
      state
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(**)
      nil
    end
  end

  class InvalidArgumentsCommandModel
    def initialize
      @command = InvalidArgumentsCommand.new
    end

    def initial_state
      0
    end

    def commands(_state)
      [@command]
    end
  end

  class InvalidArgumentsCommand
    def name
      :bad_arguments
    end

    def arguments
      :not_an_arbitrary
    end

    def applicable?(_state)
      true
    end

    def next_state(state, _args)
      state
    end

    def run!(_sut, _args)
      nil
    end

    def verify!(**)
      nil
    end
  end
  # standard:enable Lint/ConstantDefinitionInBlock
end
