# frozen_string_literal: true

require "spec_helper"
require "pbt/stateful/command"

RSpec.describe Pbt::Stateful::CommandBuilder do
  def build_command(name: :op, weight: 1, &block)
    builder = described_class.new(name: name, weight: weight)
    block.call(builder)
    builder.build
  end

  describe "validation" do
    it "rejects non-Symbol names and non-positive Integer weights" do
      expect { described_class.new(name: "push", weight: 1) }.to raise_error(Pbt::Stateful::InvalidSpec, /Symbol/)
      expect { described_class.new(name: :push, weight: 0) }.to raise_error(Pbt::Stateful::InvalidSpec, /positive Integer/)
      expect { described_class.new(name: :push, weight: 1.5) }.to raise_error(Pbt::Stateful::InvalidSpec, /positive Integer/)
    end

    it "requires run and rejects duplicate hook definitions" do
      expect { build_command {} }.to raise_error(Pbt::Stateful::InvalidSpec, /must define run/)

      expect {
        build_command do |c|
          c.guard { true }
          c.guard { false }
          c.run { nil }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /guard already defined/)

      expect {
        build_command do |c|
          c.arguments Pbt.integer
          c.arguments Pbt.integer
          c.run { nil }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /arguments already defined/)
    end

    it "rejects invalid arguments signatures" do
      expect {
        build_command do |c|
          c.arguments 123
          c.run { nil }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /must be an arbitrary/)

      expect {
        build_command do |c|
          c.arguments(Pbt.integer, x: Pbt.integer)
          c.run { nil }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /cannot mix positional and keyword/)

      expect {
        build_command do |c|
          c.arguments(Pbt.integer) { Pbt.integer }
          c.run { nil }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /either a value, keyword arbitraries, or a block/)
    end
  end

  describe "command behavior" do
    it "defaults guard to true, arguments to Pbt.nil, precondition to true, next_state to identity" do
      cmd = build_command do |c|
        c.run { |sut, _args| sut }
      end

      expect(cmd.guard?(:state)).to be(true)
      expect(cmd.arguments_for(:state).generate(Random.new(1))).to be_nil
      expect(cmd.precondition?(:state, nil)).to be(true)
      expect(cmd.next_state(:state, nil, Pbt::Stateful::Ref.new(step_id: 0))).to eq(:state)
      expect(cmd.verify!(nil)).to be_nil
    end

    it "supports keyword arguments shorthand as Pbt.fixed_hash" do
      cmd = build_command do |c|
        c.arguments(amount: Pbt.constant(10), note: Pbt.constant("hi"))
        c.run { |_sut, args| args }
      end

      arb = cmd.arguments_for({})
      expect(arb.generate(Random.new(1))).to eq({amount: 10, note: "hi"})
    end

    it "supports state-dependent arguments blocks and propagates EmptyDomainError" do
      cmd = build_command do |c|
        c.arguments { |s| Pbt.constant_from(*s) }
        c.run { |_sut, args| args }
      end

      expect(cmd.arguments_for([:a, :b]).generate(Random.new(1))).to satisfy { |v| [:a, :b].include?(v) }
      expect { cmd.arguments_for([]) }.to raise_error(Pbt::Arbitrary::EmptyDomainError)
    end

    it "raises InvalidSpec if arguments block returns a non-arbitrary" do
      cmd = build_command do |c|
        c.arguments { |_s| :not_an_arb }
        c.run { nil }
      end

      expect { cmd.arguments_for({}) }.to raise_error(Pbt::Stateful::InvalidSpec, /must return an arbitrary/)
    end

    it "deep-freezes next_state output and translates FrozenError into helpful ModelError" do
      cmd = build_command(name: :push) do |c|
        c.next_state { |s, x| s << x }
        c.run { nil }
      end

      frozen_state = Pbt::Stateful::Resolver.deep_freeze([])
      expect {
        cmd.next_state(frozen_state, 1, Pbt::Stateful::Ref.new(step_id: 0))
      }.to raise_error(Pbt::Stateful::ModelError, /attempted to mutate frozen model state.*Return a new state value/)
    end

    it "supports 2-arg and 3-arg next_state lambdas" do
      cmd2 = build_command do |c|
        c.next_state(&->(s, x) { [*s, x] })
        c.run { nil }
      end
      cmd3 = build_command do |c|
        c.next_state(&->(s, x, ref) { [*s, [x, ref]] })
        c.run { nil }
      end

      ref = Pbt::Stateful::Ref.new(step_id: 4)
      expect(cmd2.next_state([].freeze, 1, ref)).to eq([1])
      expect(cmd3.next_state([].freeze, 1, ref)).to eq([[1, ref]])
    end

    it "wraps callback exceptions in ModelError and re-raises fatal exceptions" do
      buggy = build_command(name: :buggy) do |c|
        c.guard { raise "guard exploded" }
        c.run { nil }
      end
      expect { buggy.guard?({}) }.to raise_error(Pbt::Stateful::ModelError, /command :buggy guard raised RuntimeError: guard exploded/)

      fatal = build_command(name: :fatal) do |c|
        c.precondition { raise NoMemoryError, "oom" }
        c.run { nil }
      end
      expect { fatal.precondition?({}, nil) }.to raise_error(NoMemoryError, "oom")
    end
  end
end
