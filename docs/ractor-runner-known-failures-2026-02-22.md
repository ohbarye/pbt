# Ractor Runner Known Failures (Triage Memo)

- Date: 2026-02-22
- Branch at time of check: `codex/stateful-pbt-mvp-e2e-dx`
- Purpose: record existing `worker: :ractor` failures observed during the stateful PBT spike, without mixing that work into the stateful branch scope

## Summary

`spec/pbt/check/configuration_spec.rb` currently has 2 failing examples in the existing `:ractor` runner path.
These failures reproduce independently of the stateful PBT specs and appear unrelated to `Pbt.stateful(...)`.

The stateful work intentionally rejects `worker: :ractor` with `Pbt::InvalidConfiguration` for now.
This memo is only about pre-existing `Pbt.property(...)` + `worker: :ractor` failures.

## Reproduction

```bash
mise exec -- bundle exec rspec spec/pbt/check/configuration_spec.rb
```

Observed result during triage:

- `8 examples, 2 failures`

Failing examples:

- `Pbt::Check::Configuration configuration worker :ractor when all cases pass reports success`
- `Pbt::Check::Configuration configuration worker :ractor when any cases fail reports failure`

## Observations

### Failure 1 (`when all cases pass`)

Expected (spec):

- `num_runs: 5`

Observed:

- `num_runs: 1`
- `failed: false`

### Failure 2 (`when any cases fail`)

Expected (spec):

- `failed: true`
- `num_runs: 3`
- `num_shrinks: 1`
- `counterexample: 2`

Observed:

- `failed: false`
- `num_runs: 1`
- `num_shrinks: 0`
- `counterexample: nil`

## Likely scope

The symptom suggests an issue in the existing `:ractor` runner execution path (collection/iteration/result handling), not in the new stateful property implementation.

Relevant files to inspect later (separate track):

- `lib/pbt/check/runner_methods.rb`
- `lib/pbt/check/runner_iterator.rb`
- `lib/pbt/check/property.rb`

## State for stateful PBT spike

- `spec/pbt/stateful/property_spec.rb` and `spec/e2e/stateful_e2e_spec.rb` are green.
- `Pbt.stateful(...)` currently supports `worker: :none` only and rejects `worker: :ractor` explicitly.

