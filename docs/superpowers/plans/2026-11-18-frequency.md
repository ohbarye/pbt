# Weighted generation implementation plan

> Execution: native implementation with TDD and independent reviews.

**Goal:** `Pbt.frequency([3, arb], [1, other])` chooses generators by integer weight.
**Architecture:** Preserve ordinary generated values. A per-value Sample contains lazy shrink
children; standard properties use samples internally so provenance survives eager Ractor
generation and composition. No global cache or last-generated-branch state.
**Tech stack:** Ruby >= 3.3, RSpec, Standard, no runtime dependencies.
**Spec:** User-approved weighted-generator API; existing `generate`/`shrink` compatibility.

## Contract and constraints
- Nonnegative integer weights; at least one positive weight; reject malformed pairs/generators.
- Zero-weight branches are never generated; selection uses the supplied RNG without float rounding.
- Shrinking stays inside the selected branch (no cross-branch candidates).
- `generate` returns plain values. `sample` returns a value plus its shrink tree.
- Bare `frequency.shrink(value)` returns no candidates because plain values lack provenance.
  Use normal `Pbt.property` execution or `sample` to retain it. Stateful command arguments
  retain their existing plain-value protocol, so frequency argument shrinking is conservative.
- Arrays, tuples, hashes, map, filter propagate sample provenance; custom generate/shrink
  arbitraries and stateful properties fall back to their existing protocol.
- Preserve existing candidate ordering and seed behavior for existing arbitraries.

## Steps
- [ ] Add specs for integer interval boundaries, weights, determinism, invalid inputs,
  safe shrink trees after later generations, shared/composed generators and Ractor execution.
- [ ] Run specs red, review tests and this plan, commit tests before implementation.
- [ ] Implement Sample in `lib/pbt/arbitrary/sample.rb`, frequency arbitrary and factory.
- [ ] Propagate samples in composite arbitraries and standard property/runner/case/iterator.
- [ ] Run full RSpec and Standard; document usage and limitations in README/API docs.
- [ ] Review, fix and re-review; commit and open an independent PR referencing #26.

## Review focus
Equal values from different generators; pre-generation before shrinking; nested composition;
custom duck-typed arbitraries; plain-value reporting and compatibility with stateful properties.

Progress: red tests reviewed and committed d4b1fa3. Implementation passes 201 specs.
Correction: tuple sum=10 assertion overpromised existing halving shrink algorithm;
independent investigation confirmed [0,14], corrected regression expectation.
External Ruby floor/CI edits remain outside this PR.
