## [Unreleased]

- Add seed-reproducible edge-case / boundary-value bias to built-in numeric and ranged arbitraries (`IntegerArbitrary`, `FloatArbitrary`, `ChooseArbitrary`, and large `ArrayArbitrary`/`Pbt.string` lengths) to surface common boundary cases (`0`, `min`, `max`, `0.0`, `-0.0`, empty/max lengths) much more frequently ([#83](https://github.com/ohbarye/pbt/issues/83)). Note: because PRNG draw sequences and shrink order changed, seeds from v0.9.0 will generate different values and counterexamples.
- Add `Pbt.string` (printable ASCII default), rewrite `FloatArbitrary` as a direct `Arbitrary` subclass with `min:`, `max:`, `allow_nan:`, and `allow_infinity:` plus float-aware binary-search shrinking (removing unused `FLOAT_MAPPER`/`FLOAT_UNMAPPER`), and fix `ChooseArbitrary` generation/shrinking for `Float` and exclusive ranges ([#85](https://github.com/ohbarye/pbt/issues/85)).
- Add `Arbitrary#bind` / `#flat_map` (`BindArbitrary`) for dependent value generation with integrated `Sample` shrinking ([#84](https://github.com/ohbarye/pbt/issues/84)).
- Improve `IntegerArbitrary#shrink` to yield binary-search candidates toward `target`, enabling greedy shrinking to converge to exact failure thresholds ([#82](https://github.com/ohbarye/pbt/issues/82)).

## [0.9.0] - 2026-11-23

- [Breaking change] Replace `Pbt.stateful(model:, sut:)` with a redesigned yield-based DSL (`Pbt.stateful(max_steps:, min_steps:, max_shrink_attempts:) { |m| ... }`) featuring `initial_state` (value, block, or shrinkable `Arbitrary`), `sut`+`teardown` / `around` lifecycle, weighted commands (`guard`, `arguments`, `precondition`, `next_state`, `run`, `verify`), `invariant`s, symbolic `Ref`s, best-first shrinking with offline `cover?` validation and `FailureSignature` equivalence, `property.replay`, `Pbt.statistics` support, and multiline counterexample reporting [#67](https://github.com/ohbarye/pbt/issues/67) [#79](https://github.com/ohbarye/pbt/pull/79) [#80](https://github.com/ohbarye/pbt/pull/80).
  - Migration note: replace `Pbt.stateful(model:, sut:)` and per-command classes (`applicable?`, `run!`, `verify!`) with `Pbt.stateful { |m| m.initial_state ...; m.sut { ... }; m.command(:name) { |c| c.guard ...; c.arguments ...; c.next_state ...; c.run ...; c.verify ... } }`. See `README.md` for full examples.
- Add complete RBS type signatures under `sig/` (`sig/pbt.rbs`, `sig/pbt/*.rbs`, `sig/manifest.yaml`) with `rbs validate` and `steep check` in CI [#81](https://github.com/ohbarye/pbt/pull/81).
- Tighten `pbt.gemspec` packaged file allowlist to ship `lib/`, `sig/`, and root documentation only.
- Automatically create a GitHub Release in `.github/workflows/release.yml` when releasing a gem.

## [0.8.0] - 2026-11-22

- [Breaking change] Drop support for Ruby 3.2 and earlier (EOL); Ruby 3.3 or later is now required, and Ruby 4.1.0-preview1 is added to CI [#66](https://github.com/ohbarye/pbt/pull/66)
- [Breaking change] Split literal constant selection into `Pbt.constant_from(*choices)` and change `Pbt.one_of(*arbitraries)` to select uniformly among arbitraries with contextual shrinking [#70](https://github.com/ohbarye/pbt/pull/70)
- Add `Pbt.frequency` weighted generators with contextual lazy shrink trees (`Arbitrary::Sample`) [#61](https://github.com/ohbarye/pbt/pull/61)
- Add `Pbt.statistics` for reproducible generator distribution inspection [#62](https://github.com/ohbarye/pbt/pull/62)
- Allow `Arbitrary#map` without an `unmapper` and with block syntax (`arb.map { |v| ... }`), shrinking via `Sample` provenance [#71](https://github.com/ohbarye/pbt/pull/71)
- Add 3-valued `Arbitrary#cover?(value)` (including `FloatArbitrary` for `Pbt.float`) and `RunnerIterator` `same_failure?` / `shrink_case` hooks [#72](https://github.com/ohbarye/pbt/pull/72)
- Document v1 Property DSL contract and fix positional Hash / strict lambda argument passing in `Check::Property#run` [#73](https://github.com/ohbarye/pbt/pull/73)
- Re-raise fatal exceptions (`SystemExit`, `SignalException`, `NoMemoryError`) in runners without shrinking [#74](https://github.com/ohbarye/pbt/pull/74)
- Bound `FilterArbitrary` generation retries with `max_attempts:` (raising `Pbt::Arbitrary::FilterExhaustedError`) to prevent infinite loops [#75](https://github.com/ohbarye/pbt/pull/75)
- Improve array shrinking (continue element shrinking at `min_length` and support non-contiguous element deletion) and fix `Pbt.nat` default `max` [#76](https://github.com/ohbarye/pbt/pull/76)
- Add `Pbt.assume` precondition helper with `max_skips` guard (`Pbt::TooManySkipsError`) and `RunDetails#num_skips` [#77](https://github.com/ohbarye/pbt/pull/77)
- Note: the current `Pbt.stateful(model:, sut:)` API is planned to be replaced with a redesigned DSL in v0.9.0 ([#67](https://github.com/ohbarye/pbt/issues/67)).

## [0.7.0] - 2026-04-04

- [Breaking change] Simplify stateful command protocol: `arguments` must now accept `state` parameter, and `applicable?` must now accept both `state` and `args` parameters
- Make `rng` optional in all arbitrary `generate` methods with default `Random.new` [#44](https://github.com/ohbarye/pbt/pull/44)
- Mark stateful testing API as stable (no longer experimental)

## [0.6.0] - 2026-03-15

- Add experimental `Pbt.stateful` API for model-based stateful property testing [#38](https://github.com/ohbarye/pbt/pull/38)
- Support state-aware and arg-aware stateful command protocols, including argument shrinking and generation edge cases [#40](https://github.com/ohbarye/pbt/pull/40)
- Validate stateful model/command contracts more consistently and improve diagnostics [#39](https://github.com/ohbarye/pbt/pull/39)
- Add Ruby 4.0 to CI test matrix

## [0.5.1] - 2025-06-29

- Fix `IntegerArbitrary#shrink` to respect min/max bounds [#36](https://github.com/ohbarye/pbt/pull/36)

## [0.5.0] - 2024-12-30

- [Breaking change] Drop `:process` and `:thread` workers since there are no concrete use cases.
- [Breaking change] Drop `:experimental_ractor_rspec_integration` option since there are no concrete use cases.

## [0.4.2] - 2024-05-23

- Fix Prism `LoadError` message [#27](https://github.com/ohbarye/pbt/pull/27) by @sambostock

## [0.4.1] - 2024-05-10

- Fix a bug for experimental_ractor_rspec_integration mode. When a test file name starts with a number, it can't be a constant name.

## [0.4.0] - 2024-05-06

- Allow to use RSpec::Matchers for `worker: :none, :thread, :process` also.
- Make error message short to keep focusing on failure causes.
- Fix a bug for a case when parameters cannot be passed to a test block correctly.

## [0.3.0] - 2024-04-21

- Add experimental_ractor_rspec_integration mode. Be careful, it's quite experimental.
- Fix a bug: consider a case when a backtrace is nil.
- Allow to pass a predicate block keyword arguments with destruction.

## [0.2.0] - 2024-04-17

- Add verbose mode. It's useful to debug the test case.

## [0.1.1] - 2024-04-14

- Change default worker from `:ractor` to `:none`

## [0.1.0] - 2024-04-13

- Implement basic primitive arbitraries
- Implement composite arbitraries
- Support shrinking
- Support multiple concurrency methods
  - Ractor
  - Process
  - Thread
  - None (Run tests sequentially)
- Documentation
  - Add better examples
  - Arbitrary usage
  - Configuration

## [0.0.1] - 2024-01-27

- Initial release (Proof of concept)
