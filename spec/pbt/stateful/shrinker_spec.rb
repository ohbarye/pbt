# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pbt::Stateful::Shrinker do
  def build_spec(&block)
    builder = Pbt::Stateful::SpecBuilder.new
    block.call(builder)
    builder.build
  end

  def make_sample(run, initial_state_sample: nil, step_samples: {}, max_attempts: 1_000)
    Pbt::Stateful::RunSample.new(
      run,
      initial_state_sample: initial_state_sample,
      step_samples: step_samples,
      session: Pbt::Stateful::ShrinkSession.new(max_attempts: max_attempts)
    )
  end

  it "immediately truncates unexecuted steps after the failing step_index" do
    spec = build_spec do |m|
      m.initial_state 0
      m.sut { Object.new }
      m.command(:inc) do |c|
        c.next_state { |s| s + 1 }
        c.run { nil }
      end
    end

    steps = (0..4).map { |id| Pbt::Stateful::Step.new(id: id, command: :inc, args: nil) }
    run = Pbt::Stateful::Run.new(initial_state: 0, steps: steps)
    failure = Pbt::Stateful::StepFailure.new(
      "step 2 inc [verify]: boom",
      step_index: 1,
      step: steps[1],
      stage: :verify,
      target: :inc,
      exception_class: RuntimeError
    )

    first = described_class.new(spec).shrink(make_sample(run), failure: failure).first
    expect(first.run.steps.map(&:id)).to eq([0, 1])
  end

  it "immediately truncates all steps when initial invariant fails" do
    spec = build_spec do |m|
      m.initial_state 0
      m.sut { Object.new }
      m.command(:inc) { |c| c.run { nil } }
    end

    steps = (0..2).map { |id| Pbt::Stateful::Step.new(id: id, command: :inc, args: nil) }
    run = Pbt::Stateful::Run.new(initial_state: 0, steps: steps)
    failure = Pbt::Stateful::StepFailure.new(
      "initial [invariant]: bad",
      step_index: nil,
      step: nil,
      stage: :invariant,
      target: :always_positive,
      exception_class: RuntimeError
    )

    first = described_class.new(spec).shrink(make_sample(run), failure: failure).first
    expect(first.run.steps).to eq([])
  end

  it "performs ddmin chunk deletions before single-step deletions, back to front" do
    spec = build_spec do |m|
      m.initial_state 0
      m.sut { Object.new }
      m.command(:inc) { |c| c.run { nil } }
    end

    steps = (0..3).map { |id| Pbt::Stateful::Step.new(id: id, command: :inc, args: nil) }
    run = Pbt::Stateful::Run.new(initial_state: 0, steps: steps)
    candidates = described_class.new(spec).shrink(make_sample(run), failure: nil).map { |s| s.run.steps.map(&:id) }

    expect(candidates).to eq([
      [0, 1],       # chunk deletion of [2, 3]
      [2, 3],       # chunk deletion of [0, 1]
      [0, 1, 2],    # single deletion of 3
      [0, 1, 3],    # single deletion of 2
      [0, 2, 3],    # single deletion of 1
      [1, 2, 3]     # single deletion of 0
    ])
  end

  it "rejects candidates whose args fail Arbitrary#cover? for the new state" do
    spec = build_spec do |m|
      m.initial_state 0
      m.sut { Object.new }
      m.command(:deposit) do |c|
        c.arguments Pbt.integer(min: 1, max: 100)
        c.next_state { |s, amount| s + amount }
        c.run { nil }
      end
      m.command(:withdraw) do |c|
        c.guard { |s| s > 0 }
        c.arguments { |s| Pbt.integer(min: 1, max: s) }
        c.next_state { |s, amount| s - amount }
        c.run { nil }
      end
    end

    shrinker = described_class.new(spec)
    # Deposit 5 then deposit 10 then withdraw 12: deleting deposit(10) leaves balance=5,
    # where withdraw's arguments arbitrary is 1..5, so cover?(12) == false!
    steps = [
      Pbt::Stateful::Step.new(id: 0, command: :deposit, args: 5),
      Pbt::Stateful::Step.new(id: 1, command: :deposit, args: 10),
      Pbt::Stateful::Step.new(id: 2, command: :withdraw, args: 12)
    ]
    run = Pbt::Stateful::Run.new(initial_state: 0, steps: steps)

    expect(shrinker.valid_run?(run)).to be(true)
    invalid = Pbt::Stateful::Run.new(initial_state: 0, steps: [steps[0], steps[2]])
    expect(shrinker.valid_run?(invalid)).to be(false)
  end

  it "rejects candidates with dangling Ref dependencies before calling precondition" do
    precondition_saw_dangling_ref = false
    spec = build_spec do |m|
      m.initial_state({}.freeze)
      m.sut { Object.new }
      m.command(:create) do |c|
        c.next_state { |s, _args, ref| s.merge(ref => :open) }
        c.run { :id }
      end
      m.command(:close) do |c|
        c.guard { |s| !s.empty? }
        c.arguments { |s| Pbt.constant_from(*s.keys) }
        c.precondition do |s, id|
          precondition_saw_dangling_ref = true unless s.key?(id)
          s.fetch(id) == :open
        end
        c.next_state { |s, id| s.merge(id => :closed) }
        c.run { nil }
      end
    end

    ref0 = Pbt::Stateful::Ref.new(step_id: 0)
    steps = [
      Pbt::Stateful::Step.new(id: 0, command: :create, args: nil),
      Pbt::Stateful::Step.new(id: 1, command: :close, args: ref0)
    ]
    dangling = Pbt::Stateful::Run.new(initial_state: {}.freeze, steps: [steps[1]])

    expect(described_class.new(spec).valid_run?(dangling)).to be(false)
    expect(precondition_saw_dangling_ref).to be(false)
  end

  it "deduplicates seen runs and honors the shared max_shrink_attempts budget" do
    spec = build_spec do |m|
      m.initial_state 0
      m.sut { Object.new }
      m.command(:inc) do |c|
        c.arguments Pbt.integer(min: 1, max: 10)
        c.next_state { |s, x| s + x }
        c.run { nil }
      end
    end

    steps = (0..4).map { |id| Pbt::Stateful::Step.new(id: id, command: :inc, args: 5) }
    run = Pbt::Stateful::Run.new(initial_state: 0, steps: steps)
    sample = make_sample(run, max_attempts: 3)

    emitted = described_class.new(spec).shrink(sample, failure: nil).to_a
    expect(emitted.size).to eq(3)
    expect(sample.session.attempts).to eq(3)
    expect(emitted.map(&:run).uniq.size).to eq(3)
  end

  it "shrinks initial_state and step arguments via captured Samples" do
    spec = build_spec do |m|
      m.initial_state Pbt.integer(min: 0, max: 100)
      m.sut { Object.new }
      m.command(:add) do |c|
        c.arguments Pbt.integer(min: 1, max: 100)
        c.next_state { |s, x| s + x }
        c.run { nil }
      end
    end

    init_sample = Pbt::Arbitrary::Sample.from_value(Pbt.integer(min: 0, max: 100), 10)
    arg_sample = Pbt::Arbitrary::Sample.from_value(Pbt.integer(min: 1, max: 100), 10)
    step = Pbt::Stateful::Step.new(id: 0, command: :add, args: 10)
    run = Pbt::Stateful::Run.new(initial_state: 10, steps: [step])

    candidates = described_class.new(spec).shrink(
      make_sample(run, initial_state_sample: init_sample, step_samples: {0 => arg_sample}),
      failure: nil
    ).map(&:run)

    # Order: single deletion -> initial_state shrinks -> step arg shrinks
    expect(candidates.first).to eq(Pbt::Stateful::Run.new(initial_state: 10, steps: []))
    expect(candidates.any? { |r| r.initial_state == 0 && r.steps == [step] }).to be(true)
    expect(candidates.any? { |r| r.initial_state == 10 && r.steps.first&.args == 1 }).to be(true)
  end
end
