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

    it "generates executable command sequences that respect preconditions" do
      property = Pbt.stateful(model:, sut: -> { CorrectStack.new }, max_steps: 10)
      sequence = property.generate(Random.new(1234))

      expect { property.run(sequence) }.not_to raise_error
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
  end

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

    def verify!(before_state: _, after_state:, args: _, result: _, sut:)
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

    def verify!(before_state:, after_state: _, args: _, result:, sut:)
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
end
