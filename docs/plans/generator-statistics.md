# Generator statistics

Goal: inspect generated value distributions independently of property execution.
API: `Pbt.statistics(arb, num_runs: 100, seed: Random.new_seed) { |value| label }`.
Return seed, num_runs, counts and unrounded percentages; no block counts values.
Runs must be a nonnegative integer. Zero generates/classifies nothing. Use a local
seeded RNG, propagate errors and keep each invocation independent. Values or classifier
labels used as Hash keys must be stable (not mutated by later generation).

- [x] Write tests, run red (12 failures, missing API), review contract/tests.
- [ ] Commit tests before implementation.
- [ ] Add statistics class and Pbt entry point, docs and full suite/lint.
- [ ] Independent review, fix/re-review, commit, PR referencing #26.
