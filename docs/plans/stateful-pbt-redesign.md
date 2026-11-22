# Stateful Property-Based Testing Redesign

- **Tracking issue**: [#67](https://github.com/ohbarye/pbt/issues/67) (related to [#26](https://github.com/ohbarye/pbt/issues/26))
- **Baseline commit**: `main` at `c0ef6d0890636d0f21244b75584709e713ace1b2`
- **Ruby baseline**: `>= 3.3` (already enforced in `pbt.gemspec`; CI covers Ruby 3.3–4.1 preview)
- **Scope**: Clean-slate replacement of the experimental `Pbt.stateful` API and engine. Backward compatibility with the old `Pbt.stateful(model:, sut:)` protocol is intentionally dropped. Ractor support is optional.

---

## 1. Context & Baseline Capabilities on `main`

Recent merges on `main` directly shape this design:

1. **Ruby `>= 3.3` (`pbt.gemspec`, PR #66)**: `Data.define` is available unconditionally in library code. Internal library files must avoid `it` (Ruby 3.4+) so Ruby 3.3 stays green, while single-argument callbacks allow Ruby 3.4 / 4.x users to write `it` idiomatically in their tests.
2. **Contextual lazy shrink trees & weighted generators (`lib/pbt/arbitrary/sample.rb`, `frequency_arbitrary.rb`, PR #61)**:
   - `Pbt::Arbitrary::Sample.capture(arb, rng)` preserves generator provenance (`#value` + lazy `#shrink`).
   - `FrequencyArbitrary#shrink(bare_value)` intentionally returns an empty Enumerator because bare values lose branch provenance. Therefore, the stateful engine **must** generate and shrink `initial_state` and step `args` via `Sample.capture`, not bare `generate`/`shrink`.
   - `Check::Tosser` already calls `property.generate_for_check(rng)` when available, and `Check::RunnerMethods#build_case` already extracts `Arbitrary::Sample` into `Case#sample`.
3. **Generator statistics (`lib/pbt/statistics.rb`, PR #62)**: `Pbt.statistics(arbitrary, num_runs:, seed:, &classifier)` samples via `arbitrary.generate(rng)` and uses returned values/labels as Hash keys (requiring immutable values).
4. **Workers (`lib/pbt/check/runner_methods.rb`, PR #65)**: v1 supports only `:none` and `:ractor` (bare Fiber worker was rejected). Stateful properties default to `:none` and reject explicit `worker: :ractor` before generation.

---

## 2. Prior-Art Research & Architectural Choice

### 2.1 Taxonomy of Stateful PBT Paradigms

| Paradigm | Representative Libraries | Core Abstraction | Shrinking Requirement | Fit for `ohbarye/pbt` |
|---|---|---|---|---|
| **Imperative rule-based machine** | Python `Hypothesis` (`RuleBasedStateMachine`), Go `rapid` (`t.Repeat`), Ruby `zizek`, `Hegel` (2026) | Mutable state + rules calling `draw(arb)` + `assume` + `invariant` + `Bundle` | Requires internal choice-sequence (Conjecture/bitstream) shrinking | Poor fit for v1 without rewriting all of `Pbt::Arbitrary` into a choice-sequence engine; couples model and SUT |
| **Pure model + command transition** | Erlang `eqc_statem` / `proper_statem`, Elixir `PropCheck.StateM.ModelDSL`, Haskell `Hedgehog`, Rust `proptest-state-machine` | Pure model (`initial_state`, `guard`/`precondition`, `next_state`) + command (`arguments`, `run`, `verify`) + `invariant` | Works cleanly with value/sample-based shrinking (sequence reduction + `Sample#shrink` + offline model validation) | **Best fit**: aligns with `pbt`'s pure-Ruby zero-dep architecture, `Arbitrary::Sample`, and future parallel/linearizability testing |
| **Mutable-model command pattern** | TS/JS `fast-check` (`fc.commands` + `fc.modelRun`) | `Command<Model, Real>` with `check(m)`, `run(m, r)`, `toString()` | External/tree shrinking over command arrays | `model` and `real` updates are interleaved in `run`; awkward for state-dependent argument generation |
| **Fluent ActionChain** | Java/Kotlin `jqwik` (`ActionChain`, `Independent` / `Dependent`) | Fluent chain + `Transformer` + `withInvariant` | Integrated shrinking (`Shrinkable`) | Verbose and merges model/SUT into one state container |

### 2.2 Key Lessons Imported from Prior Art

1. **Two-stage applicability (Haskell `Hedgehog` & Rust `proptest-state-machine`)**: Separate a state-only `guard(state)` (evaluated *before* `arguments(state)`) from an optional arg-aware `precondition(state, args)`. Combine with `Arbitrary#cover?(value)` so state-dependent argument domains are automatically re-validated during shrinking without duplicating bounds in `precondition`.
2. **Cohesive command blocks with sensible defaults (Elixir `PropCheck.StateM.ModelDSL`)**: Co-locate all hooks of one command inside `command :name do |c| ... end`; omit `guard`, `arguments`, `precondition`, `next_state`, and `verify` when trivial.
3. **Global invariants & lifecycle hooks (Hypothesis, `rapid`, `proptest-state-machine`)**: Support `invariant` (checked after SUT initialization and after every command) and `sut`+`teardown` / `around` with guaranteed `ensure` cleanup.
4. **Weighted commands & arbitrary initial state (`jqwik`, `proptest-state-machine`)**: First-class `weight:` on commands and arbitrary `initial_state` (including shrinking the initial state).
5. **Symbolic references (Erlang `proper_statem`, Haskell `Hedgehog`)**: Keep model transitions strictly symbolic (`Ref` tokens) and resolve concrete SUT results only at execution/verification time so SUT bugs never corrupt model state.
6. **Swarm testing & coverage diagnostics (Groce et al., Hypothesis, Antithesis)**: Planned for Phase 2 once the core model engine is rock-solid.

---

## 3. Audit of Current Experimental `Pbt.stateful`

The current implementation in `lib/pbt/stateful/property.rb` is being discarded due to these issues:

1. **Severe boilerplate**: Even a 1-command counter requires a model class plus a command class implementing 6 mandatory methods (`name`, `arguments`, `applicable?`, `next_state`, `run!`, `verify!`).
2. **Broken RSpec/Minitest ergonomics**: Separate command classes cannot call `expect(...)` or `assert_equal(...)` directly; all existing specs fall back to `raise "..." unless ...`.
3. **Ordering bug between `arguments(state)` and `applicable?(state, args)`**: Because `applicable?` requires `args`, `arguments(state)` runs even in states where the command is illegal, requiring `EmptyDomainError` hacks and retry loops.
4. **Missing essentials**: No `invariant`, `teardown`/`around`, command `weight`, arbitrary `initial_state`, symbolic references, or `replay`.
5. **Shrinking flaws**:
   - Prefix-only sequence shrinking (no post-failure truncation, no chunk/single-step subsequence deletion).
   - Calling `arguments(new_state).shrink(old_args)` after state changes violates `Arbitrary#shrink`'s domain contract (e.g., `OneOfArbitrary#shrink` passes `nil` into `IntegerArbitrary#shrink`).
   - Ignores `Arbitrary::Sample`, so `Pbt.frequency` in command arguments does not shrink.
   - No failure-equivalence check during shrinking (a shrink candidate can slip into an unrelated bug).
   - `valid_sequence?` has bare `rescue => false`, silently swallowing bugs in user model callbacks.
6. **Exception rewrapping bug**: `raise e.class, "stateful step ...", e.backtrace` raises `ArgumentError` for exception classes whose `initialize` takes custom arguments.
7. **Mutable `Step` & noisy reporting**: `Step` is a mutable `Struct`, and counterexamples print raw `Array#inspect`.

---

## 4. Public API Specification (v1)

### 4.1 Entry Point

```ruby
Pbt.stateful(max_steps: 20, min_steps: 1, max_shrink_attempts: 1_000) do |m|
  ...
end
```

- Returns a `Pbt::Stateful::Property` compatible with `Pbt.assert` and `Pbt.check`.
- Uses **yield builders (`|m|`, `|c|`)**, never `instance_eval`: preserves lexical `self` (RSpec `expect`/`let`, Minitest assertions, helper methods) and static tooling (RBS/Ruby LSP).
- `num_runs`, `seed`, and `verbose` remain options on `Pbt.assert` / `Pbt.check`.
- `min_steps` defaults to `1` (must be `>= 0`); `max_steps` defaults to `20` (must be `>= min_steps` and positive). Each generated run picks target length uniformly from `min_steps..max_steps`.
- Explicit `worker: :ractor` raises `Pbt::InvalidConfiguration` before generation begins. When `worker:` is omitted, stateful properties force `:none` even if global `Pbt.configuration.worker == :ractor`.

### 4.2 Worked Examples

#### Minimal Stack Example (Ruby 3.4/4.x `it` style)

```ruby
Pbt.assert do
  Pbt.stateful(max_steps: 30) do |m|
    m.initial_state { [] }
    m.sut { Stack.new }

    m.command :push, weight: 3 do |c|
      c.arguments Pbt.integer(min: 0, max: 100)
      c.next_state { |state, value| [*state, value] }
      c.run { |sut, value| sut.push(value) }
    end

    m.command :pop, weight: 2 do |c|
      c.guard { !it.empty? }
      c.next_state { it[0...-1] }
      c.run { it.pop }
      c.verify { expect(it.result).to eq(it.before.last) }
    end

    m.command :peek do |c|
      c.guard { !it.empty? }
      c.run { it.peek }
      c.verify { expect(it.result).to eq(it.after.last) }
    end

    m.invariant(:snapshot) { |state, sut| expect(sut.snapshot).to eq(state) }
  end
end
```

#### Full-Featured BankAccount Example (Arbitrary `initial_state`, `Data.define`, `around`/`teardown`, Symbolic `Ref`)

```ruby
BankState = Data.define(:balance, :open, :accounts)

Pbt.assert(seed: 42, num_runs: 200) do
  Pbt.stateful(max_steps: 25) do |m|
    m.initial_state Pbt.integer(min: 0, max: 100).map(
      ->(b) { BankState.new(balance: b, open: true, accounts: []) },
      ->(s) { s.balance }
    )

    m.sut { |init| Bank.open(init.balance) }
    m.teardown { |sut| sut.close }
    # Alternative block-scoped lifecycle (mutually exclusive with sut/teardown):
    # m.around { |init, run| Dir.mktmpdir { |dir| run.call(Bank.open(init.balance, dir:)) } }

    m.command :deposit, weight: 3 do |c|
      c.guard { |s| s.open }
      c.arguments Pbt.integer(min: 1, max: 50)
      c.next_state { |s, amount| s.with(balance: s.balance + amount) }
      c.run { |sut, amount| sut.deposit(amount) }
    end

    m.command :withdraw, weight: 2 do |c|
      c.guard { |s| s.open && s.balance.positive? }
      c.arguments { |s| Pbt.integer(min: 1, max: s.balance) }
      c.next_state { |s, amount| s.with(balance: s.balance - amount) }
      c.run { |sut, amount| sut.withdraw(amount) }
      c.verify { |ctx| expect(ctx.result).to eq(ctx.after.balance) }
    end

    m.command :create_sub_account do |c|
      c.guard { |s| s.open }
      c.next_state { |s, _args, ref| s.with(accounts: [*s.accounts, ref]) }
      c.run { |sut| sut.create_sub_account }
    end

    m.command :close_sub_account do |c|
      c.guard { |s| s.open && !s.accounts.empty? }
      c.arguments { |s| Pbt.constant_from(*s.accounts) }
      c.next_state { |s, ref| s.with(accounts: s.accounts - [ref]) }
      c.run { |sut, account_id| sut.close_sub_account(account_id) }
    end

    m.invariant(:balance_matches) do |state, sut|
      expect(sut.balance).to eq(state.balance)
      expect(sut.balance).to be >= 0
    end
  end
end
```

### 4.3 Builder & Command Contracts

#### Model Builder (`m`)

| Method | Signature | Default | Contract |
|---|---|---|---|
| `m.initial_state` | `(value_or_arb)` or `{ ... }` | `nil` | Accepts a constant value, an `Arbitrary`, or a deterministic zero-arg factory block. Evaluated once per generated case and stored on `Run`. Always deep-frozen. |
| `m.sut` | `{ \|initial_state\| ... }` | Required (unless `around` is given) | Creates a fresh SUT per run and per shrink candidate. |
| `m.teardown` | `{ \|sut\| ... }` | None | Runs exactly once in `ensure` if `sut` returned normally. |
| `m.around` | `{ \|initial_state, run\| ... }` | None | Mutually exclusive with `sut`/`teardown`. Internal lifecycle uses `around` uniformly (`sut`+`teardown` desugars to `around`). Must call `run.call(sut)` exactly once (raises `InvalidSpec` if 0 or >1 calls). |
| `m.command` | `(name, weight: 1) { \|c\| ... }` | — | `name` must be a unique `Symbol`; `weight` must be a positive `Integer`. |
| `m.invariant` | `(name = nil) { \|state, sut\| ... }` | None (multiple allowed) | Assertion hook (signals failure only by raising; return value ignored). Runs after SUT setup (before step 1) and after every step's `verify`. |

#### Command Builder (`c`)

| Method | Signature | Default | Contract |
|---|---|---|---|
| `c.guard` | `{ \|state\| bool }` | `true` | State-only predicate evaluated **before** `arguments(state)` during generation and re-evaluated on every shrink candidate. |
| `c.arguments` | `(arb)`, `(**kw_arbs)`, or `{ \|state\| arb }` | `Pbt.nil` | Produces a single argument value (use `Pbt.tuple` or keyword shorthand `c.arguments(k: arb)` -> `Pbt.fixed_hash` for multiple fields; never splats). Must return an object responding to `generate` and `shrink` (or `sample`). |
| `c.precondition` | `{ \|state, args\| bool }` | `true` | Optional arg-aware predicate for cross-field/custom constraints not captured by `Arbitrary#cover?`. |
| `c.next_state` | `{ \|state, args\| new_state }` or `{ \|state, args, ref\| new_state }` | Identity (`state`) | Pure transition function. Always runs in the **symbolic** domain (`ref` is `Pbt::Stateful::Ref`, never a concrete SUT result). Return value is deep-frozen. |
| `c.run` | `{ \|sut, args\| result }` | **Required** | Executes the operation on SUT with resolved concrete `args`. |
| `c.verify` | `{ \|ctx\| ... }` | None | Assertion hook (signals failure only by raising; return value ignored). Receives `Context = Data.define(:step, :before, :after, :args, :result, :sut)` with all `Ref`s resolved to concrete values. |

### 4.4 Public Value Objects (`Data.define`) & Replay

- `Pbt::Stateful::Step = Data.define(:id, :command, :args)`
  - `id`: monotonic generation-time integer (never renumbered when steps are deleted).
  - `command`: `Symbol` (never stores the Command object containing Procs).
  - `args`: symbolic generated argument value.
- `Pbt::Stateful::Run = Data.define(:initial_state, :steps)`
  - Pure, immutable, structurally comparable (`==`, `hash`, `eql?`).
  - Helper methods: `#size`, `#empty?`, `#command_names` (`steps.map(&:command)`).
  - `#to_s` / `#inspect`: program-style multi-line trace (numbering steps `1..n`, printing `v0 = ...` only for steps whose `Ref` is referenced later).
- `Pbt::Stateful::Ref = Data.define(:step_id)`
  - Opaque symbolic token referencing the return value of the step with `id == step_id`.
- `Pbt::Stateful::Context = Data.define(:step, :before, :after, :args, :result, :sut)`
- `Pbt::Stateful::FailureSignature = Data.define(:stage, :target, :exception_class)`
- `property.replay(run)`
  - Executes a `Pbt::Stateful::Run` (e.g., `details.counterexample` from `Pbt.check`) once against a fresh SUT with full `around`/`teardown`, `verify`, and `invariant` checks.
- `Pbt.statistics(property, num_runs: 100, seed: 42) { |run| ... }`
  - Works out of the box because `property.generate(rng)` returns a pure immutable `Run`.

---

## 5. Core Semantics & Edge Cases

### 5.1 `Arbitrary#cover?(value)` (3-Valued Membership Check)

Add `#cover?(value)` to `Pbt::Arbitrary::Arbitrary` returning:
- `true`: value is confirmed within this arbitrary's domain
- `false`: value is confirmed outside this arbitrary's domain
- `nil`: unknown / cannot determine reliably (default on base `Arbitrary` for custom user arbitraries)

Built-in implementations:
- `IntegerArbitrary`: `value.is_a?(Integer) && value >= @min && value <= @max` (respecting unbounded `nil` bounds if any)
- `ChooseArbitrary`: `@range.cover?(value)` (ensuring integer/range type compatibility)
- `ConstantArbitrary`: `value == @val`
- `ConstantFromArbitrary`: `@choices.include?(value)`
- `OneOfArbitrary`: `true` if any branch returns `true`; `false` if all branches return `false`; otherwise `nil`
- `FrequencyArbitrary`: `true` if any branch returns `true`; `false` if all branches return `false`; otherwise `nil`
- `TupleArbitrary`: `false` unless `value.is_a?(Array) && value.size == @arbs.size`; aggregate element `cover?` (`false` if any `false`, `true` if all `true`, else `nil`)
- `ArrayArbitrary`: `false` unless `value.is_a?(Array) && value.size.between?(@min_length, @max_length)`; aggregate element `cover?`
- `FixedHashArbitrary`: `false` unless `value.is_a?(Hash) && value.keys == @hash.keys` (or same key set); aggregate value `cover?`
- `FilterArbitrary`: combine base `cover?(value)` with `!!@refinement.call(value)` (returning `false` if refinement is falsy)
- `MapArbitrary`: attempt `@unmapper.call(value)` and delegate to `@arb.cover?(unmapped)`; rescue exceptions and return `nil`

### 5.2 Separating Pure `Run` from `Sample` Provenance

- `property.generate(rng)` returns pure `Pbt::Stateful::Run`.
- `property.generate_for_check(rng)` returns an internal provenance wrapper (compatible with `Case#sample` via `Arbitrary::Sample` or a dedicated stateful sample object whose `#value` is `Run`) containing:
  - `run` (`Pbt::Stateful::Run`)
  - `initial_state_sample` (`Arbitrary::Sample` or `nil` when `initial_state` is constant/block)
  - `step_samples` (`Hash{Integer => Arbitrary::Sample}` keyed by `step.id`)
- Because `Sample` is never stored inside `Run` or `Step`:
  - `Run#==`, `Run#hash`, `seen` deduplication, `Pbt.statistics`, `details.counterexample`, and `property.replay` remain pure and deterministic.
  - `Pbt.frequency`, `map`, `filter`, `tuple`, `array`, and `fixed_hash` inside `initial_state` and `c.arguments` all retain full contextual shrinking.

### 5.3 Generation Algorithm & Exhaustion Rules

For each case:
1. Resolve `initial_state` (capturing `Sample` if `Arbitrary`) and deep-freeze it.
2. Check eligible commands at step 0 (`guard(state)`):
   - If `initial_state` is non-arbitrary and **no** command has a truthy `guard` at step 0, raise `Pbt::Stateful::InvalidSpec` immediately (prevents silent vacuous passes).
3. Draw target length from `min_steps..max_steps` using `rng`.
4. At each step `i`:
   - Collect commands where `guard(state)` is truthy (exceptions in `guard` propagate immediately as model errors — never swallowed).
   - If no command is eligible, stop generating further steps cleanly (if `steps.empty?` across all runs, raise `GenerationError` / `InvalidSpec`).
   - Loop up to a bounded per-step attempt budget (e.g., `32` attempts):
     - Pick an eligible command weighted by `weight:` using `rng`.
     - Evaluate `arb = command.arguments_for(state)` (validate `generate`/`shrink` protocol; catch `Pbt::Arbitrary::EmptyDomainError` and mark that command ineligible for this state).
     - Capture `sample = Arbitrary::Sample.capture(arb, rng)` (note: `FilterArbitrary` can loop indefinitely if its predicate is unsatisfiable — document preferring state-bounded generators over heavy `.filter`).
     - Check `command.precondition(state, sample.value)`. If true, create `step_id = next_id`, `ref = Ref.new(step_id: step_id)`, compute `next_state = deep_freeze(command.next_state(state, sample.value, ref))`, append `Step.new(id: step_id, command: command.name, args: sample.value)`, record `step_samples[step_id] = sample`, and advance `state = next_state`.
   - If eligible commands exist but all attempts are exhausted, raise `Pbt::Stateful::GenerationError` with step index and eligible command names.

### 5.4 Symbolic References (`Ref`) Semantics

1. **Monotonic IDs**: `step.id` is assigned `0, 1, 2, ...` at generation time and never mutated during shrinking.
2. **Strict symbolic vs. concrete boundary**:
   - `guard`, `arguments`, `precondition`, and `next_state` **always** see symbolic values (`Ref`). `next_state` is never re-run with concrete SUT return values.
   - `run`, `verify`, and `invariant` **always** see resolved concrete values via `env` (`Hash{Integer => Object}`).
3. **`nil` vs. unbound**: Resolution uses `env.fetch(ref.step_id)` so a step legitimately returning `nil` resolves to `nil`, while an unbound ref is a validation bug.
4. **Scoped deep resolution**: Recursively resolve `Ref` only inside:
   - `Ref` -> `env.fetch(ref.step_id)`
   - `Array` -> `obj.map { |e| resolve(e, env) }`
   - `Hash` -> `obj.transform_keys { |k| resolve(k, env) }.transform_values { |v| resolve(v, env) }`
   - `Set` -> `Set.new(obj.map { |e| resolve(e, env) })`
   - `Struct` -> reconstruct with resolved members
   - `Data` -> `obj.with(**obj.to_h.transform_values { |v| resolve(v, env) })`
   - Any other object passes through untouched.
5. **Dependency checking**: During shrink validation, collect all `Ref` instances reachable inside `step.args` (using the same container traversal) and verify every `ref.step_id` is in the set of surviving earlier `step.id`s.
6. **Limitation (documented)**: Because `Ref` is opaque to the pure model, the model cannot branch on the concrete value returned by the SUT.

### 5.5 Shrinking Algorithm & `RunnerIterator` Integration

#### Minimal `RunnerIterator` Hook (`lib/pbt/check/runner_iterator.rb`)

Update `RunnerIterator#handle_result(c)` (~6 lines):
1. Record `@initial_failure ||= c.exception` on first failure.
2. On subsequent failures during shrinking, if `@property.respond_to?(:same_failure?) && !@property.same_failure?(@initial_failure, c.exception)`: treat candidate as non-matching (do **not** overwrite `@run_execution` failure; continue iterating `@next_values`).
3. Choose the next shrink enumerator with `shrink_case` taking precedence over `c.sample`:
   ```ruby
   @next_values =
     if @property.respond_to?(:shrink_case)
       @property.shrink_case(c)
     elsif c.sample
       c.sample.shrink
     else
       @property.shrink(c.val)
     end
   ```

#### Failure Equivalence (`FailureSignature`)

- `StepFailure` carries `signature = FailureSignature.new(stage:, target:, exception_class: cause.class)` where:
  - `stage`: `:run`, `:verify`, `:invariant`, `:sut`, or `:teardown`
  - `target`: command `Symbol` or invariant name (`Symbol` / `String` / `nil`)
  - `exception_class`: original cause exception class
- Deliberately **excludes** `step_index` because deleting earlier steps shifts indices.
- `same_failure?(initial_err, candidate_err)` compares `initial_err.signature == candidate_err.signature` (when both are `StepFailure`).
- If `teardown` fails (`teardown_error` present), stop shrinking immediately so cleanup breakage is never masked.

#### Shrink Candidate Order & Budget (`max_shrink_attempts`)

Shared per-failure budget counter (`max_shrink_attempts`, counting both invalid and valid attempts) and `seen` cache keyed by `[run.initial_state, run.steps]`:

1. **Immediate post-failure truncation**: If `c.exception` is a `StepFailure` with `step_index` and `step_index < steps.length - 1`, yield `steps[0..step_index]` first (one step drops all unexecuted trailing commands).
2. **Chunk deletions (ddmin-style)**: For chunk sizes `k = n/2, n/4, ..., 2`, scan windows from back to front and yield runs with that slice deleted.
3. **Single-step deletions**: Scan steps from back to front and yield runs with step `i` removed.
4. **`initial_state` shrinking**: If `initial_state_sample` exists, iterate `initial_state_sample.shrink` and yield runs with the smaller `initial_state` (preserving `steps`).
5. **Step argument shrinking**: For each step `i` (from step `0` to `n - 1`), iterate `step_samples[step.id].shrink` and yield runs replacing step `i`'s `args` (and updated child `Sample`).

Every candidate in stages 2–5 is validated purely on the model **before** touching the SUT:
1. `guard(state)` is truthy
2. `arb = arguments(state)` builds without `EmptyDomainError`
3. `arb.cover?(step.args) != false`
4. `precondition(state, step.args)` is truthy
5. Every `Ref` inside `step.args` is bound by an earlier surviving `step.id`
6. `state = deep_freeze(next_state(state, step.args, Ref.new(step_id: step.id)))`

Because `RunnerIterator` greedily re-invokes `shrink_case(c)` on every accepted smaller failure, this naturally reaches a fixed point (e.g., shrinking an argument can unlock another step deletion on the next pass).

### 5.6 Execution, Exceptions, State Freezing & Counterexample Formatting

1. **Execution order** (inside `lifecycle.call(resolved_initial) { |sut| ... }`):
   - Run all `invariant`s on `(resolved_initial, sut)` before step 1.
   - For each step:
     - Resolve `concrete_args = resolve(step.args, env)`.
     - Compute `before_sym = sym_state`, `after_sym = deep_freeze(command.next_state(before_sym, step.args, Ref.new(step_id: step.id)))`.
     - Execute `result = command.run!(sut, concrete_args)` (on failure -> raise `StepFailure` with `stage: :run`).
     - Store `env[step.id] = result`.
     - Resolve `before_concrete = resolve(before_sym, env)`, `after_concrete = resolve(after_sym, env)`.
     - Run `command.verify!(Context.new(step:, before: before_concrete, after: after_concrete, args: concrete_args, result:, sut:))` (on failure -> `stage: :verify`).
     - Run all `invariant`s on `(after_concrete, sut)` (on failure -> `stage: :invariant`).
     - Advance `sym_state = after_sym`.
   - Note: `after_sym` does not depend on `result`, and computing it after `run!` avoids unnecessary work when `run!` raises.
2. **State freezing**:
   - Deep-freeze `initial_state` and every `next_state` return value via `Ractor.make_shareable` (falling back to recursive container freeze / shallow `.freeze` if `Ractor::IsolationError` occurs).
   - Catch `FrozenError` inside `next_state` and raise a clear `Pbt::Stateful::ModelError` guiding the user to return a new value (`state.with(...)`, `[*arr, x]`, `hash.merge(...)`).
3. **Exception hygiene**:
   - Never rescue `SystemExit`, `SignalException`, or `NoMemoryError`.
   - Rescue `Exception` for `run`/`verify`/`invariant` so RSpec's `RSpec::Expectations::ExpectationNotMetError` (`< Exception`) is handled cleanly.
   - Wrap failures in `Pbt::Stateful::StepFailure` preserving Ruby's exception `cause` and original backtrace.
   - Run `teardown` in `ensure`. If `teardown` raises while a `StepFailure` is already propagating, keep the original `StepFailure` and attach `teardown_error` to it.
   - Never swallow exceptions raised by user model callbacks (`guard`, `arguments`, `precondition`, `next_state`) during generation or execution; surface them immediately with callback name context.
4. **Counterexample formatting (`Run#to_s`)**:
   ```text
   Property failed after 37 test(s)
     seed: 42
     counterexample:
       initial_state: #<data BankState balance=0, open=true, accounts=[]>
       1. deposit(10)
       2. v0 = create_sub_account
       3. close_sub_account(v0)
       4. withdraw(10)  # <- failed (verify)
     Shrunk 12 time(s)
     Got Pbt::Stateful::StepFailure: step 4 withdraw(10) [verify]: expected 0, got 10
       (cause: RSpec::Expectations::ExpectationNotMetError)
   ```
   (When `Run` is rendered without failure annotation—e.g. from `generate`—omit the `# <- failed (...)` comment; `StepFailure` or annotated `Run` can supply the failing step marker cleanly.)

---

## 6. Phased Implementation Plan & Resumption Guide

Follow TDD (`bundle exec rspec` red -> green) and Standard Ruby (`bundle exec rake standard`) for every PR.

### PR 0: Core Prerequisites (Small, Zero-Risk)
- **Files**:
  - `lib/pbt/arbitrary/arbitrary.rb` + all subclasses (`integer`, `choose`, `constant`, `constant_from`, `one_of`, `frequency`, `tuple`, `array`, `fixed_hash`, `filter`, `map`)
  - `lib/pbt/check/runner_iterator.rb`
  - Unit specs under `spec/pbt/arbitrary/` and `spec/pbt/check/`
- **Checklist**:
  - [ ] Implement 3-valued `Arbitrary#cover?(value)` on base class and all built-in arbitraries (including `FrequencyArbitrary`).
  - [ ] Add `same_failure?` guard and `shrink_case(c)` precedence hook to `RunnerIterator#handle_result`.
  - [ ] Verify full suite (`bundle exec rake`) passes with zero regressions on existing `Pbt.frequency` / `Sample` tests.

### PR 1: Clean-Slate `Pbt.stateful` v1
- **Files**:
  - Delete/replace `lib/pbt/stateful/property.rb`, `spec/pbt/stateful/property_spec.rb`, `spec/e2e/stateful_e2e_spec.rb`
  - Create modular files under `lib/pbt/stateful/`:
    - `errors.rb` (`InvalidSpec`, `GenerationError`, `ModelError`, `StepFailure`, `FailureSignature`)
    - `types.rb` (`Ref`, `Step`, `Run`, `Context`, `Resolver`)
    - `command.rb` (command spec & builder)
    - `spec.rb` (model spec & yield builder)
    - `shrinker.rb` (best-first shrinker + 6-step model validator + `seen` + `max_shrink_attempts`)
    - `property.rb` (`Pbt::Stateful::Property` with `generate`, `generate_for_check`, `shrink_case`, `same_failure?`, `run`, `replay`, `stateful?`, `run_in_ractor`)
  - Update `lib/pbt.rb` (`Pbt.stateful`) and `README.md`
- **Acceptance criteria**:
  - [ ] Yield-builder DSL works inside RSpec with `expect(...)` and `let` (lexical `self` preserved).
  - [ ] `initial_state` supports static value, block, and `Arbitrary` (shrunk when arbitrary); model states are deep-frozen with helpful `FrozenError` guidance.
  - [ ] `sut`+`teardown` and `around` run cleanup in `ensure` on every trial and shrink candidate; teardown errors attach to original failure and halt shrinking.
  - [ ] `guard` runs before `arguments`; `EmptyDomainError` makes a command ineligible for that state; vacuous step-0 raises `InvalidSpec`; argument exhaustion raises `GenerationError`.
  - [ ] `Pbt.frequency` inside `c.arguments` and `m.initial_state` shrinks cleanly via `Sample.capture`.
  - [ ] Symbolic `Ref` supports monotonic IDs, `nil` return values, scoped deep resolution, and dependency-safe shrinking.
  - [ ] Shrinking performs post-failure truncation, chunk/single-step deletion, initial-state shrinking, and argument shrinking with `cover?` validation and `FailureSignature` preservation.
  - [ ] `property.replay(details.counterexample)` deterministically replays the minimized `Run`.
  - [ ] `Pbt.statistics(property, num_runs:, seed:) { |run| ... }` works directly.
  - [ ] Explicit `worker: :ractor` raises `Pbt::InvalidConfiguration` before generation.
  - [ ] Full suite and Standard Ruby pass (`bundle exec rake`).

### PR 2: Exploration, Diagnostics & Reuse
- Seeded Swarm Testing (`swarm:` option driven by per-run `rng`; disabled during shrinking; retains full-command runs).
- Command execution & dead-guard coverage summary integrated with `Pbt.statistics`.
- Reusable class-based model DSL (`Pbt::Stateful::Model`) with optional Ruby 4 `Ractor.shareable_proc` support.
- Expected-error command helper and automatic final-counterexample replay to flag flaky SUTs.

### PR 3: Future Experiments
- Concurrent / linearizability testing reusing the pure sequential model over Thread/Fiber/Ractor suffixes.
- `TapeRandom` choice-sequence integrated shrinking experiment (leveraging the fact that all randomness in `pbt` flows through `rng.rand(Range)` in `IntegerArbitrary` and `ChooseArbitrary`).
