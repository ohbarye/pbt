# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pbt::Stateful::Property do
  describe "option validation" do
    it "requires a block for Pbt.stateful" do
      expect { Pbt.stateful }.to raise_error(Pbt::Stateful::InvalidSpec, /requires a block/)
    end

    it "validates min_steps, max_steps, and max_shrink_attempts" do
      base = proc do |m|
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect { Pbt.stateful(min_steps: -1, &base) }.to raise_error(Pbt::Stateful::InvalidSpec, /min_steps/)
      expect { Pbt.stateful(min_steps: 5, max_steps: 3, &base) }.to raise_error(Pbt::Stateful::InvalidSpec, /max_steps/)
      expect { Pbt.stateful(max_shrink_attempts: -1, &base) }.to raise_error(Pbt::Stateful::InvalidSpec, /max_shrink_attempts/)
    end
  end

  describe "#generate and #generate_for_check" do
    it "raises InvalidSpec when no command guard is truthy at a non-arbitrary initial_state" do
      prop = Pbt.stateful do |m|
        m.initial_state 0
        m.sut { Object.new }
        m.command(:never) do |c|
          c.guard { |s| s > 0 }
          c.run { nil }
        end
      end

      expect { prop.generate(Random.new(1)) }.to raise_error(
        Pbt::Stateful::InvalidSpec,
        /no command guard is truthy at initial_state 0/
      )
    end

    it "skips commands raising EmptyDomainError and selects other eligible commands" do
      prop = Pbt.stateful(min_steps: 3, max_steps: 3) do |m|
        m.initial_state 0
        m.sut { Object.new }
        m.command(:empty) do |c|
          c.arguments { |_s| Pbt.constant_from(*[]) }
          c.run { nil }
        end
        m.command(:ok) do |c|
          c.arguments Pbt.constant(1)
          c.next_state { |s, x| s + x }
          c.run { nil }
        end
      end

      run = prop.generate(Random.new(42))
      expect(run).to be_a(Pbt::Stateful::Run)
      expect(run.command_names).to eq([:ok, :ok, :ok])
    end

    it "stops cleanly when reaching a terminal state after min_steps" do
      prop = Pbt.stateful(min_steps: 1, max_steps: 10) do |m|
        m.initial_state :open
        m.sut { Object.new }
        m.command(:close) do |c|
          c.guard { |s| s == :open }
          c.next_state { |_s| :closed }
          c.run { nil }
        end
      end

      run = prop.generate(Random.new(1))
      expect(run.command_names).to eq([:close])
    end

    it "raises GenerationError when preconditions cannot be satisfied within attempt budget" do
      prop = Pbt.stateful(min_steps: 1, max_steps: 3) do |m|
        m.initial_state 0
        m.sut { Object.new }
        m.command(:impossible) do |c|
          c.arguments Pbt.integer(min: 1, max: 5)
          c.precondition { |_s, _x| false }
          c.run { nil }
        end
      end

      expect { prop.generate(Random.new(1)) }.to raise_error(
        Pbt::Stateful::GenerationError,
        /could not satisfy preconditions at step 0.*\[:impossible\]/
      )
    end

    it "respects command weights deterministically with rng" do
      prop = Pbt.stateful(min_steps: 100, max_steps: 100) do |m|
        m.initial_state 0
        m.sut { Object.new }
        m.command(:heavy, weight: 9) { |c| c.run { nil } }
        m.command(:light, weight: 1) { |c| c.run { nil } }
      end

      run1 = prop.generate(Random.new(42))
      run2 = prop.generate(Random.new(42))
      expect(run1).to eq(run2)
      expect(run1.command_names.count(:heavy)).to be > 75
      expect(run1.command_names.count(:light)).to be > 0
    end

    it "returns a pure Run from #generate and a RunSample from #generate_for_check" do
      prop = Pbt.stateful(min_steps: 2, max_steps: 2) do |m|
        m.initial_state Pbt.integer(min: 0, max: 5)
        m.sut { Object.new }
        m.command(:add) do |c|
          c.arguments Pbt.integer(min: 1, max: 5)
          c.next_state { |s, x| s + x }
          c.run { nil }
        end
      end

      pure_run = prop.generate(Random.new(7))
      sample = prop.generate_for_check(Random.new(7))

      expect(pure_run).to be_a(Pbt::Stateful::Run)
      expect(sample).to be_a(Pbt::Stateful::RunSample)
      expect(sample.value).to eq(pure_run)
      expect(sample.initial_state_sample).to be_a(Pbt::Arbitrary::Sample)
      expect(sample.step_samples.keys).to eq([0, 1])
    end
  end

  describe "#run and #replay" do
    it "runs initial invariants before step 1 and invariants after each step" do
      observed = []
      prop = Pbt.stateful do |m|
        m.initial_state 0
        m.sut { |s| {val: s} }
        m.invariant(:match) do |state, sut|
          observed << [state, sut[:val]]
          raise "mismatch" unless state == sut[:val]
        end
        m.command(:inc) do |c|
          c.next_state { |s| s + 1 }
          c.run { |sut| sut[:val] += 1 }
        end
      end

      run = Pbt::Stateful::Run.new(
        initial_state: 0,
        steps: [Pbt::Stateful::Step.new(id: 0, command: :inc, args: nil)]
      )
      prop.replay(run)
      expect(observed).to eq([[0, 0], [1, 1]])
    end

    it "wraps run, verify, and invariant failures in StepFailure preserving cause" do
      prop = Pbt.stateful do |m|
        m.initial_state 0
        m.sut { Object.new }
        m.command(:fail_verify) do |c|
          c.run { :ok }
          c.verify { raise ArgumentError, "bad result" }
        end
      end

      run = Pbt::Stateful::Run.new(
        initial_state: 0,
        steps: [Pbt::Stateful::Step.new(id: 0, command: :fail_verify, args: nil)]
      )

      expect { prop.replay(run) }.to raise_error(Pbt::Stateful::StepFailure) { |err|
        expect(err.stage).to eq(:verify)
        expect(err.target).to eq(:fail_verify)
        expect(err.step_index).to eq(0)
        expect(err.cause).to be_a(ArgumentError)
        expect(err.signature).to eq(
          Pbt::Stateful::FailureSignature.new(stage: :verify, target: :fail_verify, exception_class: ArgumentError)
        )
      }
    end

    it "rejects non-Run inputs to #replay" do
      prop = Pbt.stateful do |m|
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect { prop.replay([]) }.to raise_error(ArgumentError, /Pbt::Stateful::Run/)
    end
  end

  describe "#same_failure? and #shrink_case" do
    let(:prop) do
      Pbt.stateful do |m|
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end
    end

    it "matches only StepFailures with identical FailureSignature and stops on teardown_error" do
      f1 = Pbt::Stateful::StepFailure.new("a", step_index: 3, step: nil, stage: :verify, target: :withdraw, exception_class: RuntimeError)
      f2 = Pbt::Stateful::StepFailure.new("b", step_index: 0, step: nil, stage: :verify, target: :withdraw, exception_class: RuntimeError)
      f3 = Pbt::Stateful::StepFailure.new("c", step_index: 0, step: nil, stage: :run, target: :withdraw, exception_class: RuntimeError)

      expect(prop.same_failure?(f1, f2)).to be(true)
      expect(prop.same_failure?(f1, f3)).to be(false)

      f1.attach_teardown_error(IOError.new("teardown broke"))
      expect(prop.same_failure?(f1, f2)).to be(false)

      c = Pbt::Check::Case.new(val: Pbt::Stateful::Run.new(initial_state: 0, steps: []), exception: f1)
      expect(prop.shrink_case(c).to_a).to eq([])
    end
  end

  describe "#run_in_ractor" do
    it "raises InvalidConfiguration" do
      prop = Pbt.stateful do |m|
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect { prop.run_in_ractor(nil) }.to raise_error(Pbt::InvalidConfiguration, /worker: :ractor/)
    end
  end
end
