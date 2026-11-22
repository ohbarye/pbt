# frozen_string_literal: true

require "spec_helper"
require "pbt/stateful/errors"
require "pbt/stateful/types"

RSpec.describe "Pbt::Stateful core types and errors" do
  describe Pbt::Stateful::StepFailure do
    it "builds a FailureSignature excluding step_index" do
      step = Pbt::Stateful::Step.new(id: 2, command: :withdraw, args: 10)
      f1 = described_class.new(
        "step 3 withdraw(10) [verify]: bad balance",
        step_index: 2,
        step: step,
        stage: :verify,
        target: :withdraw,
        exception_class: RuntimeError
      )
      f2 = described_class.new(
        "step 1 withdraw(10) [verify]: bad balance",
        step_index: 0,
        step: step,
        stage: :verify,
        target: :withdraw,
        exception_class: RuntimeError
      )

      expect(f1.signature).to eq(f2.signature)
      expect(f1.signature).to eq(
        Pbt::Stateful::FailureSignature.new(stage: :verify, target: :withdraw, exception_class: RuntimeError)
      )
      expect(f1.teardown_error).to be_nil
    end

    it "attaches a teardown error and includes it in #message" do
      failure = described_class.new(
        "step 1 push(1) [run]: boom",
        step_index: 0,
        step: Pbt::Stateful::Step.new(id: 0, command: :push, args: 1),
        stage: :run,
        target: :push,
        exception_class: RuntimeError
      )
      teardown_err = IOError.new("failed to close")
      failure.attach_teardown_error(teardown_err)

      expect(failure.teardown_error).to eq(teardown_err)
      expect(failure.message).to include("step 1 push(1) [run]: boom")
      expect(failure.message).to include("teardown error: IOError: failed to close")
    end
  end

  describe Pbt::Stateful::Ref do
    it "formats as v<step_id> and supports structural equality" do
      ref = described_class.new(step_id: 3)
      expect(ref.to_s).to eq("v3")
      expect(ref.inspect).to eq("v3")
      expect(ref).to eq(described_class.new(step_id: 3))
      expect(ref.hash).to eq(described_class.new(step_id: 3).hash)
    end
  end

  describe Pbt::Stateful::Run do
    it "supports size, empty?, command_names, equality, and formatting with referenced Refs" do
      ref0 = Pbt::Stateful::Ref.new(step_id: 0)
      steps = [
        Pbt::Stateful::Step.new(id: 0, command: :create, args: nil),
        Pbt::Stateful::Step.new(id: 1, command: :deposit, args: 10),
        Pbt::Stateful::Step.new(id: 2, command: :close, args: ref0)
      ]
      run = described_class.new(initial_state: {balance: 0}, steps: steps)

      expect(run.size).to eq(3)
      expect(run.empty?).to be(false)
      expect(run.command_names).to eq([:create, :deposit, :close])
      expect(run).to eq(described_class.new(initial_state: {balance: 0}, steps: steps))
      expect(run.hash).to eq(described_class.new(initial_state: {balance: 0}, steps: steps).hash)

      formatted = run.format(failed_step_index: 2, failed_stage: :verify)
      expect(formatted).to eq(<<~TEXT.chomp)
        initial_state: {balance: 0}
        1. v0 = create
        2. deposit(10)
        3. close(v0)  # <- failed (verify)
      TEXT
    end

    it "formats an empty run cleanly" do
      run = described_class.new(initial_state: [], steps: [])
      expect(run.empty?).to be(true)
      expect(run.to_s).to eq("initial_state: []\n(no steps)")
    end
  end

  describe Pbt::Stateful::Resolver do
    let(:struct_class) { Struct.new(:id, :items) }
    let(:data_class) { Data.define(:ref, :label) }
    let(:empty_data_class) { Data.define }

    describe ".resolve" do
      it "resolves Refs inside nested Array, Hash keys/values, Set, Struct, and Data" do
        ref0 = Pbt::Stateful::Ref.new(step_id: 0)
        ref1 = Pbt::Stateful::Ref.new(step_id: 1)
        env = {0 => :acct_1, 1 => nil}

        struct_val = struct_class.new(ref0, [ref1]).freeze
        data_val = data_class.new(ref: ref0, label: "ok")
        empty_data = empty_data_class.new
        opaque = Object.new

        input = {
          ref0 => [ref1, Set[ref0], struct_val, data_val, empty_data, opaque]
        }

        resolved = described_class.resolve(input, env)
        expect(resolved.keys).to eq([:acct_1])

        values = resolved[:acct_1]
        expect(values[0]).to be_nil
        expect(values[1]).to eq(Set[:acct_1])
        expect(values[2]).to eq(struct_class.new(:acct_1, [nil]))
        expect(values[2]).to be_frozen
        expect(values[3]).to eq(data_class.new(ref: :acct_1, label: "ok"))
        expect(values[4]).to equal(empty_data)
        expect(values[5]).to equal(opaque)
      end

      it "raises KeyError for an unbound Ref while allowing nil bound values" do
        expect(described_class.resolve(Pbt::Stateful::Ref.new(step_id: 0), {0 => nil})).to be_nil
        expect {
          described_class.resolve(Pbt::Stateful::Ref.new(step_id: 99), {0 => nil})
        }.to raise_error(KeyError)
      end
    end

    describe ".collect_ref_ids" do
      it "collects Ref ids across containers including cyclic graphs without infinite recursion" do
        ref0 = Pbt::Stateful::Ref.new(step_id: 0)
        ref2 = Pbt::Stateful::Ref.new(step_id: 2)
        cyclic = [ref0]
        cyclic << cyclic
        nested = {
          key: struct_class.new(ref2, Set[cyclic]),
          data: data_class.new(ref: ref0, label: "x")
        }

        expect(described_class.collect_ref_ids(nested)).to eq(Set[0, 2])
      end
    end

    describe ".deep_freeze" do
      it "freezes nested containers via Ractor.make_shareable" do
        state = {items: [1, 2], nested: {a: "x"}}
        frozen_state = described_class.deep_freeze(state)

        expect(frozen_state).to be_frozen
        expect(frozen_state[:items]).to be_frozen
        expect(frozen_state[:nested]).to be_frozen
      end

      it "falls back to recursive container freeze when an object is not Ractor-shareable" do
        non_shareable = proc { 1 }
        state = {fn: non_shareable, list: [1, 2]}
        frozen_state = described_class.deep_freeze(state)

        expect(frozen_state).to be_frozen
        expect(frozen_state[:list]).to be_frozen
      end
    end

    describe ".invoke_with_arity" do
      it "passes only as many positional args as the callable accepts" do
        expect(described_class.invoke_with_arity(-> { :zero }, 1, 2, 3)).to eq(:zero)
        expect(described_class.invoke_with_arity(->(a) { a * 10 }, 2, 3)).to eq(20)
        expect(described_class.invoke_with_arity(->(a, b) { a + b }, 2, 3, 4)).to eq(5)
        expect(described_class.invoke_with_arity(->(*xs) { xs }, 1, 2, 3)).to eq([1, 2, 3])
      end

      it "works with custom callables without #parameters" do
        callable = Object.new
        callable.define_singleton_method(:call) { |a, b| a + b }
        expect(described_class.invoke_with_arity(callable, 3, 4)).to eq(7)
      end
    end
  end
end
