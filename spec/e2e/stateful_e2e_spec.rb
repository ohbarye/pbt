# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pbt.stateful end-to-end" do
  let(:helper_limit) { 10 }

  it "preserves lexical self inside callbacks so RSpec expect and let work directly" do
    Pbt.assert(seed: 42, num_runs: 10) do
      Pbt.stateful(max_steps: 5) do |m|
        m.initial_state 0
        m.sut { {count: 0} }

        m.invariant(:non_negative) do |state, sut|
          expect(sut[:count]).to eq(state)
          expect(state).to be >= 0
        end

        m.command(:add) do |c|
          c.arguments Pbt.integer(min: 1, max: helper_limit)
          c.next_state { |s, n| s + n }
          c.run { |sut, n| sut[:count] += n }
          c.verify do |ctx|
            expect(ctx.result).to eq(ctx.after)
            expect(ctx.after - ctx.before).to eq(ctx.args)
          end
        end
      end
    end
  end

  it "shrinks arbitrary initial_state and detects deep-freeze mutation mistakes" do
    # Bug triggers whenever initial_state >= 1 and add >= 5
    details = Pbt.check(seed: 1, num_runs: 50) do
      Pbt.stateful(min_steps: 1, max_steps: 6) do |m|
        m.initial_state Pbt.integer(min: 0, max: 100)
        m.sut { |s| {init: s, val: s} }

        m.command(:add) do |c|
          c.arguments Pbt.integer(min: 1, max: 50)
          c.next_state { |s, x| s + x }
          c.run do |sut, x|
            sut[:val] += x
            raise "overflow" if sut[:init] >= 1 && x >= 5
            sut[:val]
          end
        end
      end
    end

    expect(details.failed).to be(true)
    expect(details.num_shrinks).to be > 0
    expect(details.counterexample.steps.size).to eq(1)
    expect(details.counterexample.initial_state).to eq(1)
    expect(details.counterexample.initial_state).to be < details.failures.first.val.initial_state
    expect(details.counterexample.steps.first.args).to be >= 5

    expect {
      Pbt.check(seed: 1, num_runs: 1) do
        Pbt.stateful do |m|
          m.initial_state({items: []})
          m.sut { Object.new }
          m.command(:mutate) do |c|
            c.next_state { |s| s[:items] << 1 }
            c.run { nil }
          end
        end
      end
    }.to raise_error(Pbt::Stateful::ModelError, /attempted to mutate frozen model state/)
  end

  it "runs sut+teardown and around cleanup on every trial and shrink, and halts shrinking on teardown failure" do
    open_handles = 0
    max_open = 0

    details = Pbt.check(seed: 7, num_runs: 20) do
      Pbt.stateful(min_steps: 1, max_steps: 5) do |m|
        m.initial_state 0
        m.sut do
          open_handles += 1
          max_open = [max_open, open_handles].max
          {val: 0}
        end
        m.teardown { |_sut| open_handles -= 1 }

        m.command(:add) do |c|
          c.arguments Pbt.integer(min: 1, max: 20)
          c.next_state { |s, x| s + x }
          c.run do |sut, x|
            sut[:val] += x
            raise "boom" if sut[:val] >= 15
          end
        end
      end
    end

    expect(details.failed).to be(true)
    expect(open_handles).to eq(0)
    expect(max_open).to eq(1)

    around_cleaned = 0
    Pbt.assert(seed: 3, num_runs: 5) do
      Pbt.stateful(max_steps: 3) do |m|
        m.initial_state 0
        m.around do |s, run|
          sut = {val: s}
          run.call(sut)
        ensure
          around_cleaned += 1
        end
        m.command(:inc) do |c|
          c.next_state { |s| s + 1 }
          c.run { |sut| sut[:val] += 1 }
        end
      end
    end
    expect(around_cleaned).to eq(5)

    # Teardown error attaches to StepFailure and halts shrinking immediately
    teardown_details = Pbt.check(seed: 2, num_runs: 10) do
      Pbt.stateful(min_steps: 4, max_steps: 4) do |m|
        m.initial_state 0
        m.sut { Object.new }
        m.teardown { |_sut| raise IOError, "socket stuck" }
        m.command(:fail_step) do |c|
          c.run { raise "step failed" }
        end
      end
    end

    expect(teardown_details.failed).to be(true)
    expect(teardown_details.num_shrinks).to eq(0)
    expect(teardown_details.error_instance).to be_a(Pbt::Stateful::StepFailure)
    expect(teardown_details.error_instance.teardown_error).to be_a(IOError)
    expect(teardown_details.error_message).to include("teardown error: IOError: socket stuck")
  end

  it "shrinks Pbt.frequency and block #map inside c.arguments and m.initial_state" do
    details = Pbt.check(seed: 42, num_runs: 50) do
      Pbt.stateful(min_steps: 1, max_steps: 5) do |m|
        m.initial_state Pbt.frequency(
          [1, Pbt.integer(min: 0, max: 50).map { |n| {start: n} }],
          [1, Pbt.integer(min: 50, max: 100).map { |n| {start: n} }]
        )
        m.sut { |s| {val: s[:start]} }

        m.command(:apply) do |c|
          c.arguments Pbt.frequency(
            [1, Pbt.integer(min: 1, max: 100).map { |n| {delta: n} }],
            [1, Pbt.integer(min: 1, max: 100).map { |n| {delta: n * 2} }]
          )
          c.next_state { |s, args| {start: s[:start] + args[:delta]} }
          c.run do |sut, args|
            sut[:val] += args[:delta]
            raise "too big" if args[:delta] >= 20
          end
        end
      end
    end

    expect(details.failed).to be(true)
    expect(details.num_shrinks).to be > 0
    expect(details.counterexample.steps.size).to eq(1)
    expect(details.counterexample.steps.first.args[:delta]).to eq(20)
    expect([0, 50]).to include(details.counterexample.initial_state[:start])
  end

  it "supports symbolic Refs including nil return values, scoped deep resolution, and dependency-safe shrinking" do
    account_sut_class = Class.new do
      def initialize
        @next_id = 100
        @accounts = {}
      end

      def create_account
        id = :"acct_#{@next_id}"
        @next_id += 1
        @accounts[id] = {balance: 0, open: true}
        id
      end

      def noop_nil
        nil
      end

      def check_nil(val)
        raise "expected nil, got #{val.inspect}" unless val.nil?
      end

      def deposit(id, amount)
        @accounts.fetch(id)[:balance] += amount
      end

      def close(id)
        # Bug: closing an account with balance >= 10 forgets to mark it closed
        return false if @accounts.fetch(id)[:balance] >= 10

        @accounts.fetch(id)[:open] = false
        true
      end

      def open?(id)
        @accounts.fetch(id)[:open]
      end
    end

    state_class = Data.define(:accounts, :nil_refs)

    property = Pbt.stateful(min_steps: 2, max_steps: 12) do |m|
      m.initial_state state_class.new(accounts: {}, nil_refs: [])
      m.sut { account_sut_class.new }

      m.command(:create) do |c|
        c.next_state { |s, _args, ref| s.with(accounts: s.accounts.merge(ref => {balance: 0, open: true})) }
        c.run { |sut| sut.create_account }
      end

      m.command(:make_nil) do |c|
        c.next_state { |s, _args, ref| s.with(nil_refs: [*s.nil_refs, ref]) }
        c.run { |sut| sut.noop_nil }
      end

      m.command(:use_nil) do |c|
        c.guard { |s| !s.nil_refs.empty? }
        c.arguments { |s| Pbt.constant_from(*s.nil_refs) }
        c.run { |sut, val| sut.check_nil(val) }
      end

      m.command(:deposit) do |c|
        c.guard { |s| s.accounts.any? { |_, info| info[:open] } }
        c.arguments do |s|
          open_refs = s.accounts.select { |_, info| info[:open] }.keys
          Pbt.fixed_hash(id: Pbt.constant_from(*open_refs), amount: Pbt.integer(min: 1, max: 30))
        end
        c.next_state do |s, args|
          acct = s.accounts.fetch(args[:id])
          s.with(accounts: s.accounts.merge(args[:id] => acct.merge(balance: acct[:balance] + args[:amount])))
        end
        c.run { |sut, args| sut.deposit(args[:id], args[:amount]) }
      end

      m.command(:close) do |c|
        c.guard { |s| s.accounts.any? { |_, info| info[:open] } }
        c.arguments do |s|
          open_refs = s.accounts.select { |_, info| info[:open] }.keys
          Pbt.constant_from(*open_refs)
        end
        c.next_state do |s, id|
          acct = s.accounts.fetch(id)
          s.with(accounts: s.accounts.merge(id => acct.merge(open: false)))
        end
        c.run { |sut, id| sut.close(id) }
        c.verify do |ctx|
          expect(ctx.sut.open?(ctx.args)).to be(false)
        end
      end
    end

    details = Pbt.check(seed: 42, num_runs: 80) { property }
    expect(details.failed).to be(true)

    ce = details.counterexample
    expect(ce.command_names).to eq([:create, :deposit, :close])
    expect(ce.steps[1].args[:amount]).to eq(10)
    expect(details.num_shrinks).to be > 0
    # Same symbolic Ref links create -> deposit -> close
    created_ref = Pbt::Stateful::Ref.new(step_id: ce.steps[0].id)
    expect(ce.steps[1].args[:id]).to eq(created_ref)
    expect(ce.steps[2].args).to eq(created_ref)

    # Deterministic replay reproduces the exact same failure
    expect { property.replay(ce) }.to raise_error(Pbt::Stateful::StepFailure) { |err|
      expect(err.signature).to eq(details.error_instance.signature)
    }

    # Pbt.statistics works directly on the stateful property
    stats = Pbt.statistics(property, num_runs: 20, seed: 42) { |run| run.command_names.first }
    expect(stats.counts.values.sum).to eq(20)
    expect(stats.seed).to eq(42)
  end

  it "preserves FailureSignature during shrinking and does not slip into an unrelated failure" do
    error_a = Class.new(StandardError)
    error_b = Class.new(StandardError)

    details = Pbt.check(seed: 1, num_runs: 20) do
      Pbt.stateful(min_steps: 2, max_steps: 4) do |m|
        m.initial_state 0
        m.sut { {steps: 0} }

        m.command(:op) do |c|
          c.arguments Pbt.integer(min: 1, max: 10)
          c.next_state { |s, x| s + x }
          c.run do |sut, x|
            sut[:steps] += 1
            # When shrinking x to 1 on step 1, an unrelated error_b fires;
            # shrinker must reject error_b and keep error_a (which triggers for x >= 2).
            raise error_b, "unrelated" if x == 1
            raise error_a, "target bug" if x >= 2
          end
        end
      end
    end

    expect(details.failed).to be(true)
    expect(details.error_instance.signature.exception_class).to eq(error_a)
    expect(details.counterexample.steps.size).to eq(1)
    expect(details.counterexample.steps.first.args).to eq(2)
  end

  it "formats multiline stateful counterexamples with failing step marker and cause in Pbt.assert" do
    expect {
      Pbt.assert(seed: 1, num_runs: 20) do
        Pbt.stateful(min_steps: 2, max_steps: 4) do |m|
          m.initial_state 0
          m.sut { {balance: 0} }

          m.command(:deposit) do |c|
            c.arguments Pbt.integer(min: 1, max: 20)
            c.next_state { |s, x| s + x }
            c.run { |sut, x| sut[:balance] += x }
            c.verify do |ctx|
              expect(ctx.sut[:balance]).to be < 10
            end
          end
        end
      end
    }.to raise_error(Pbt::PropertyFailure) { |err|
      expect(err.message).to include("counterexample:\n    initial_state: 0")
      expect(err.message).to include("# <- failed (verify)")
      expect(err.message).to include("Got Pbt::Stateful::StepFailure:")
      expect(err.message).to include("(cause: RSpec::Expectations::ExpectationNotMetError)")
    }
  end

  it "defaults to :none when global worker is :ractor, and rejects explicit worker: :ractor before generation" do
    generated = false
    prop = Pbt.stateful do |m|
      m.initial_state do
        generated = true
        0
      end
      m.sut { Object.new }
      m.command(:noop) { |c| c.run { nil } }
    end

    expect {
      Pbt.assert(worker: :ractor, num_runs: 5, seed: 1) { prop }
    }.to raise_error(Pbt::InvalidConfiguration, /worker: :ractor/)
    expect(generated).to be(false)

    original_worker = Pbt.configuration.worker
    begin
      Pbt.configure { |config| config.worker = :ractor }
      result = Pbt.check(num_runs: 3, seed: 1) { prop }
      expect(result.failed).to be(false)
      expect(generated).to be(true)
    ensure
      Pbt.configure { |config| config.worker = original_worker }
    end
  end

  it "isolates mutable String/Array args and initial_state from SUT mutations while allowing mutating SUTs" do
    # SUT mutating String arg does not corrupt counterexample or break replay
    mut_arg_prop = Pbt.stateful(max_steps: 1) do |m|
      m.initial_state []
      m.sut { [] }
      m.command(:edit) do |c|
        c.arguments Pbt.constant(:input).map { +"a" }
        c.next_state { |s, str| [*s, str] }
        c.run do |sut, arg|
          arg.force_encoding(Encoding::BINARY)
          sut << arg
          raise "boom" if arg.slice!(0) == "a"
        end
      end
    end

    d = Pbt.check(num_runs: 1, seed: 1) { mut_arg_prop }
    expect(d.failed).to be(true)
    expect(d.counterexample.steps.first.args).to eq("a")
    expect { mut_arg_prop.replay(d.counterexample) }.to raise_error(Pbt::Stateful::StepFailure, /boom/)

    # SUT mutating initial_state copy is still caught by initial invariant
    mut_init_prop = Pbt.stateful(max_steps: 1) do |m|
      m.initial_state []
      m.sut { |initial| initial << :unexpected }
      m.invariant { |expected, sut| raise "bad state" unless sut == expected }
      m.command(:clear) { |c| c.run { |sut| sut.clear } }
    end

    init_d = Pbt.check(num_runs: 1, seed: 1) { mut_init_prop }
    expect(init_d.failed).to be(true)
    expect(init_d.error_instance.stage).to eq(:invariant)
  end

  it "distinguishes multiple unnamed invariants in FailureSignature during shrinking" do
    prop = Pbt.stateful(max_steps: 8, min_steps: 8) do |m|
      m.initial_state({n: 0, flagged_at_zero: false})
      m.sut { {} }
      m.command(:inc) do |c|
        c.next_state { |s| s.merge(n: s[:n] + 1) }
        c.run { nil }
      end
      m.command(:flag) do |c|
        c.next_state { |s| (s[:n] == 0) ? s.merge(flagged_at_zero: true) : s }
        c.run { nil }
      end
      m.invariant { |s, _| raise "A: n reached 3" if s[:n] >= 3 }
      m.invariant { |s, _| raise "B: flag at zero" if s[:flagged_at_zero] }
    end

    d = Pbt.check(num_runs: 1, seed: 3) { prop }
    expect(d.failed).to be(true)
    expect(d.error_message).to include("A: n reached 3")
    expect(d.counterexample.command_names).to eq([:inc, :inc, :inc])
  end

  it "surfaces teardown errors introduced during shrinking or on Pbt.assume-skipped trials" do
    cleanups = []
    shrink_td = Pbt.check(num_runs: 1, seed: 1) do
      Pbt.stateful(min_steps: 2, max_steps: 2) do |m|
        m.sut { [] }
        m.teardown do |sut|
          cleanups << sut.size
          raise IOError, "leak" if sut.size == 1
        end
        m.command(:append) do |c|
          c.run do |sut|
            sut << :item
            raise "boom" if sut.size == 2
          end
        end
      end
    end

    expect(shrink_td.failed).to be(true)
    expect(shrink_td.error_instance.stage).to eq(:teardown)
    expect(shrink_td.error_instance.teardown_error).to be_a(IOError)
    expect(cleanups).to eq([2, 1])

    skip_td = Pbt.check(seed: 0, num_runs: 1) do
      Pbt.stateful(max_steps: 1) do |m|
        m.initial_state Pbt.integer(min: 0, max: 1)
        m.sut { |n| n }
        m.teardown { |n| raise IOError, "leak" if n.zero? }
        m.command(:check) { |c| c.run { |n| Pbt.assume(n == 1) } }
      end
    end

    expect(skip_td.failed).to be(true)
    expect(skip_td.error_instance.stage).to eq(:teardown)
    expect(skip_td.error_instance.teardown_error).to be_a(IOError)
  end
end
