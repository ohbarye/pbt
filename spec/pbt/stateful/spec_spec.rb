# frozen_string_literal: true

require "spec_helper"
require "pbt/stateful/spec"

RSpec.describe Pbt::Stateful::SpecBuilder do
  def build_spec(&block)
    builder = described_class.new
    block.call(builder)
    builder.build
  end

  describe "validation" do
    it "requires at least one command and either sut or around" do
      expect {
        build_spec { |m| m.sut { Object.new } }
      }.to raise_error(Pbt::Stateful::InvalidSpec, /at least one command/)

      expect {
        build_spec do |m|
          m.command(:noop) { |c| c.run { nil } }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /must define sut or around/)
    end

    it "rejects duplicate command names" do
      expect {
        build_spec do |m|
          m.sut { Object.new }
          m.command(:push) { |c| c.run { nil } }
          m.command(:push) { |c| c.run { nil } }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /duplicate command name: :push/)
    end

    it "rejects combining around with sut or teardown, and teardown without sut" do
      expect {
        build_spec do |m|
          m.sut { Object.new }
          m.around { |_s, run| run.call(Object.new) }
          m.command(:noop) { |c| c.run { nil } }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /around cannot be combined with sut or teardown/)

      expect {
        build_spec do |m|
          m.around { |_s, run| run.call(Object.new) }
          m.teardown { |_sut| nil }
          m.command(:noop) { |c| c.run { nil } }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /teardown cannot be combined with around/)

      expect {
        build_spec do |m|
          m.teardown { |_sut| nil }
          m.command(:noop) { |c| c.run { nil } }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /teardown requires sut/)
    end

    it "rejects invalid initial_state declarations" do
      expect {
        build_spec do |m|
          m.initial_state
          m.sut { Object.new }
          m.command(:noop) { |c| c.run { nil } }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /requires a value, an arbitrary, or a block/)

      expect {
        build_spec do |m|
          m.initial_state(1) { 2 }
          m.sut { Object.new }
          m.command(:noop) { |c| c.run { nil } }
        end
      }.to raise_error(Pbt::Stateful::InvalidSpec, /not both/)
    end
  end

  describe "initial_state sampling" do
    it "treats a constant Array as a constant initial state rather than an arbitrary" do
      original = [1, 2]
      spec = build_spec do |m|
        m.initial_state original
        m.sut { [] }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect(spec.arbitrary_initial_state?).to be(false)
      val, sample = spec.sample_initial_state(Random.new(1))
      expect(val).to eq([1, 2])
      expect(val).to be_frozen
      expect(sample).to be_nil
      expect(original).not_to be_frozen
    end

    it "supports constant, block, and arbitrary initial states and deep-freezes them" do
      const_spec = build_spec do |m|
        m.initial_state({items: []})
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end
      val, sample = const_spec.sample_initial_state(Random.new(1))
      expect(val).to eq({items: []})
      expect(val).to be_frozen
      expect(val[:items]).to be_frozen
      expect(sample).to be_nil
      expect(const_spec.arbitrary_initial_state?).to be(false)

      block_spec = build_spec do |m|
        m.initial_state { [1, 2] }
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end
      bval, bsample = block_spec.sample_initial_state(Random.new(1))
      expect(bval).to eq([1, 2])
      expect(bval).to be_frozen
      expect(bsample).to be_nil

      arb_spec = build_spec do |m|
        m.initial_state Pbt.integer(min: 1, max: 10)
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end
      aval, asample = arb_spec.sample_initial_state(Random.new(1))
      expect(aval).to be_between(1, 10)
      expect(asample).to be_a(Pbt::Arbitrary::Sample)
      expect(arb_spec.arbitrary_initial_state?).to be(true)
    end

    it "wraps initial_state block failures in ModelError" do
      spec = build_spec do |m|
        m.initial_state { raise "broken init" }
        m.sut { Object.new }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect { spec.sample_initial_state(Random.new(1)) }.to raise_error(
        Pbt::Stateful::ModelError,
        /initial_state raised RuntimeError: broken init/
      )
    end
  end

  describe "sut + teardown lifecycle" do
    it "runs teardown in ensure even when body raises StepFailure" do
      events = []
      spec = build_spec do |m|
        m.sut do |s|
          events << [:sut, s]
          :my_sut
        end
        m.teardown { |sut| events << [:teardown, sut] }
        m.command(:noop) { |c| c.run { nil } }
      end

      step_failure = Pbt::Stateful::StepFailure.new(
        "boom",
        step_index: 0,
        step: nil,
        stage: :run,
        target: :noop,
        exception_class: RuntimeError
      )

      expect {
        spec.with_sut(:init) do |sut|
          events << [:body, sut]
          raise step_failure
        end
      }.to raise_error(Pbt::Stateful::StepFailure) { |err|
        expect(err).to equal(step_failure)
        expect(err.teardown_error).to be_nil
      }

      expect(events).to eq([[:sut, :init], [:body, :my_sut], [:teardown, :my_sut]])
    end

    it "attaches teardown error to propagating StepFailure without masking it" do
      spec = build_spec do |m|
        m.sut { :my_sut }
        m.teardown { |_sut| raise IOError, "close failed" }
        m.command(:noop) { |c| c.run { nil } }
      end

      original = Pbt::Stateful::StepFailure.new(
        "verify failed",
        step_index: 0,
        step: nil,
        stage: :verify,
        target: :noop,
        exception_class: RuntimeError
      )

      expect {
        spec.with_sut(:init) { |_sut| raise original }
      }.to raise_error(Pbt::Stateful::StepFailure) { |err|
        expect(err).to equal(original)
        expect(err.teardown_error).to be_a(IOError)
        expect(err.message).to include("teardown error: IOError: close failed")
      }
    end

    it "raises a :teardown StepFailure when body succeeds and teardown fails" do
      spec = build_spec do |m|
        m.sut { :my_sut }
        m.teardown { |_sut| raise IOError, "close failed" }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect {
        spec.with_sut(:init) { |_sut| :ok }
      }.to raise_error(Pbt::Stateful::StepFailure) { |err|
        expect(err.stage).to eq(:teardown)
        expect(err.teardown_error).to be_a(IOError)
      }
    end

    it "raises a :teardown StepFailure when body skips via PreconditionNotMet and teardown fails" do
      spec = build_spec do |m|
        m.sut { :my_sut }
        m.teardown { |_sut| raise IOError, "leak on skip" }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect {
        spec.with_sut(:init) { |_sut| Pbt.assume(false) }
      }.to raise_error(Pbt::Stateful::StepFailure) { |err|
        expect(err.stage).to eq(:teardown)
        expect(err.teardown_error).to be_a(IOError)
      }
    end

    it "skips teardown if sut setup itself fails and raises a :sut StepFailure" do
      teardown_called = false
      spec = build_spec do |m|
        m.sut { raise "cannot connect" }
        m.teardown { |_sut| teardown_called = true }
        m.command(:noop) { |c| c.run { nil } }
      end

      expect {
        spec.with_sut(:init) { |_sut| :never }
      }.to raise_error(Pbt::Stateful::StepFailure) { |err|
        expect(err.stage).to eq(:sut)
        expect(err.teardown_error).to be_nil
      }
      expect(teardown_called).to be(false)
    end
  end

  describe "around lifecycle" do
    it "runs around block cleanly and enforces run called exactly once" do
      events = []
      spec = build_spec do |m|
        m.around do |s, run|
          events << [:before, s]
          run.call(:wrapped_sut)
        ensure
          events << :after
        end
        m.command(:noop) { |c| c.run { nil } }
      end

      spec.with_sut(:init) { |sut| events << [:body, sut] }
      expect(events).to eq([[:before, :init], [:body, :wrapped_sut], :after])
    end

    it "raises InvalidSpec if around never calls run or calls run more than once (even if rescued)" do
      never_spec = build_spec do |m|
        m.around { |_s, _run| nil }
        m.command(:noop) { |c| c.run { nil } }
      end
      expect { never_spec.with_sut(:init) { nil } }.to raise_error(Pbt::Stateful::InvalidSpec, /called 0 times/)

      twice_spec = build_spec do |m|
        m.around do |_s, run|
          run.call(:a)
          run.call(:b)
        end
        m.command(:noop) { |c| c.run { nil } }
      end
      expect { twice_spec.with_sut(:init) { nil } }.to raise_error(Pbt::Stateful::InvalidSpec, /called 2 times/)

      rescued_twice_spec = build_spec do |m|
        m.around do |_s, run|
          run.call(:a)
          run.call(:b)
        rescue Pbt::Stateful::InvalidSpec
          nil
        end
        m.command(:noop) { |c| c.run { nil } }
      end
      expect { rescued_twice_spec.with_sut(:init) { nil } }.to raise_error(Pbt::Stateful::InvalidSpec, /called 2 times/)
    end

    it "preserves ModelError instead of misclassifying as :teardown when around cleanup also raises" do
      spec = build_spec do |m|
        m.around do |_s, run|
          run.call(:sut)
        ensure
          raise IOError, "cleanup boom"
        end
        m.command(:noop) { |c| c.run { nil } }
      end

      expect {
        spec.with_sut(:init) { |_sut| raise Pbt::Stateful::ModelError, "bad model" }
      }.to raise_error(Pbt::Stateful::ModelError, "bad model")
    end

    it "raises InvalidSpec if around returns while the body fiber is still suspended" do
      spec = build_spec do |m|
        m.around do |_s, run|
          fiber = Fiber.new { run.call(:sut) }
          fiber.resume
        end
        m.command(:noop) { |c| c.run { nil } }
      end

      expect {
        spec.with_sut(:init) { |_sut| Fiber.yield }
      }.to raise_error(Pbt::Stateful::InvalidSpec, /complete before returning/)
    end

    it "attaches cleanup error raised in around ensure to propagating StepFailure" do
      spec = build_spec do |m|
        m.around do |_s, run|
          run.call(:sut)
        ensure
          raise IOError, "cleanup boom"
        end
        m.command(:noop) { |c| c.run { nil } }
      end

      original = Pbt::Stateful::StepFailure.new(
        "run boom",
        step_index: 0,
        step: nil,
        stage: :run,
        target: :noop,
        exception_class: RuntimeError
      )

      expect {
        spec.with_sut(:init) { |_sut| raise original }
      }.to raise_error(Pbt::Stateful::StepFailure) { |err|
        expect(err).to equal(original)
        expect(err.teardown_error).to be_a(IOError)
      }
    end
  end
end
