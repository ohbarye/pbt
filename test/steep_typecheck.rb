# frozen_string_literal: true

# Consumer-side Steep typecheck smoke tests verifying public API ergonomics & generic inference.
# Uses `# @type var` annotations so this file is both strictly checked by Steep and valid Ruby.

# 1. Configuration
Pbt.configure do |config|
  config.verbose = false
  config.worker = :none
  config.num_runs = 5
  config.seed = 42
  config.thread_report_on_exception = false
  config.max_skips = 50
end

# 2. Arbitraries & generic inference
# @type var int_val: Integer
int_val = Pbt.integer(min: 0, max: 10).generate

# @type var nat_val: Integer
nat_val = Pbt.nat(max: 10).generate

# @type var arr_val: Array[String]
arr_val = Pbt.array(Pbt.ascii_string(min: 1, max: 5), min: 0, max: 3, empty: true).generate

# @type var tuple_val: Array[untyped]
tuple_val = Pbt.tuple(Pbt.integer, Pbt.symbol).generate

# @type var fixed_hash_val: Hash[untyped, untyped]
fixed_hash_val = Pbt.fixed_hash(x: Pbt.integer, y: Pbt.boolean).generate

# @type var choose_val: Integer | Float
choose_val = Pbt.choose(1..5).generate

# @type var mapped_val: String
mapped_val = Pbt.integer.map { |n| n.to_s }.generate

# @type var mapped_proc_val: String
mapped_proc_val = Pbt.integer.map(->(n) { n.to_s }, ->(s) { s.to_i }).generate

# @type var bound_val: Array[Integer]
bound_val = Pbt.integer(min: 0, max: 10).flat_map { |n| Pbt.array(Pbt.constant(n), min: 1, max: 2) }.generate

# @type var bound_proc_val: String
bound_proc_val = Pbt.integer(min: 0, max: 5).bind(->(n) { Pbt.constant(n.to_s) }).generate

# @type var filtered_val: Integer
filtered_val = Pbt.integer.filter(max_attempts: 100) { |n| n.even? }.generate

# @type var freq_val: Integer?
freq_val = Pbt.frequency([3, Pbt.integer], [1, Pbt.constant(nil)]).generate

# @type var one_of_val: Integer | String
one_of_val = Pbt.one_of(Pbt.integer, Pbt.ascii_string).generate

# @type var const_from_val: Symbol
const_from_val = Pbt.constant_from(:a, :b).generate

# @type var hash_val: Hash[Symbol, Integer]
hash_val = Pbt.hash(Pbt.symbol, Pbt.integer, min: 0, max: 3).generate

# @type var pbt_obj_hash: Integer
pbt_obj_hash = Pbt.hash

# @type var set_val: Set[Integer]
set_val = Pbt.set(Pbt.integer, min: 0, max: 3).generate

# @type var float_val: Float
float_val = Pbt.float.generate

# @type var nil_val: nil
nil_val = Pbt.nil.generate

# @type var date_val: Date
date_val = Pbt.date.generate

# @type var time_val: Time
time_val = Pbt.time.generate

# @type var sample: Pbt::Arbitrary::Sample[Integer]
sample = Pbt.integer.sample(Random.new(1))
# @type var sv: Integer
sv = sample.value
# @type var ss: Enumerator[Pbt::Arbitrary::Sample[Integer], untyped]
ss = sample.shrink

# @type var cov: bool?
cov = Pbt.integer.cover?(1)

_ = [
  int_val, nat_val, arr_val, tuple_val, fixed_hash_val, choose_val,
  mapped_val, mapped_proc_val, bound_val, bound_proc_val, filtered_val, freq_val, one_of_val,
  const_from_val, hash_val, pbt_obj_hash, set_val, float_val, nil_val,
  date_val, time_val, sv, ss, cov
]

# 3. Stateless properties, Pbt.assume, Pbt.assert, Pbt.check
Pbt.assert(num_runs: 5, seed: 42, worker: :none) do
  Pbt.property(Pbt.integer(min: 0, max: 10), Pbt.ascii_string(max: 3)) do |n, str|
    Pbt.assume(n >= 0)
    # @type var total: Integer
    total = n + str.length
    raise "unexpected" if total < 0
  end
end

# @type var details: Pbt::Reporter::RunDetails
details = Pbt.check(num_runs: 5, seed: 42) do
  Pbt.property(x: Pbt.integer, y: Pbt.integer) do |x:, y:|
    _ = [x, y]
  end
end
# @type var failed: bool
failed = details.failed
# @type var skips: Integer
skips = details.num_skips
_ = [failed, skips]

# 4. Statistics
# @type var stats: Pbt::Statistics[Symbol]
stats = Pbt.statistics(Pbt.integer, num_runs: 5, seed: 1) { |n| n.negative? ? :neg : :pos }
# @type var counts: Hash[Symbol, Integer]
counts = stats.counts
# @type var pct: Hash[Symbol, Float]
pct = stats.percentages
_ = [counts, pct]

# 5. Stateful DSL (sut + teardown), replay, statistics
# @type var stateful_prop: Pbt::Stateful::Property
stateful_prop = Pbt.stateful(min_steps: 1, max_steps: 5, max_shrink_attempts: 100) do |m|
  m.initial_state 0
  m.sut { |init| [init] }
  m.teardown { |_sut| nil }
  m.invariant(:non_neg) { |_state, _sut| nil }

  m.command(:inc, weight: 2) do |c|
    c.guard { |_s| true }
    c.arguments Pbt.integer(min: 1, max: 10)
    c.precondition { |_s, _args| true }
    c.next_state { |s, _args, _ref| s }
    c.run { |_sut, _args| nil }
    c.verify do |ctx|
      # @type var step: Pbt::Stateful::Step
      step = ctx.step
      _ = [step, ctx.before, ctx.after, ctx.args, ctx.result, ctx.sut]
    end
  end

  m.command(:kw_op) do |c|
    c.arguments(a: Pbt.integer(min: 1, max: 5))
    c.run { |_sut, _args| nil }
  end

  m.command(:dyn_op) do |c|
    c.arguments { |_s| Pbt.constant(1) }
    c.run { |_sut, _args| nil }
  end
end

# @type var around_prop: Pbt::Stateful::Property
around_prop = Pbt.stateful(max_steps: 3) do |m|
  m.initial_state { [] }
  m.around { |init, run| run.call(init) }
  m.command(:noop) { |c| c.run { |_sut, _args| nil } }
end

# @type var run: Pbt::Stateful::Run
run = stateful_prop.generate(Random.new(1))
# @type var names: Array[Symbol]
names = run.command_names
stateful_prop.replay(run)

# @type var stateful_details: Pbt::Reporter::RunDetails
stateful_details = Pbt.check(num_runs: 3, seed: 1) { around_prop }
_ = [names, stateful_details.counterexample]

# @type var stateful_stats: Pbt::Statistics[Integer]
stateful_stats = Pbt.statistics(stateful_prop, num_runs: 3, seed: 1) { |r| r.size }
# @type var sc: Hash[Integer, Integer]
sc = stateful_stats.counts
_ = sc
