# Usage recipes
Goal: runnable answer to #30 covering FactoryBot/Faker, encodings, integer ranges.
Scope: examples/usage with its own Gemfile to avoid adding optional runtime/test dependencies.
Scripts raise on violated invariants and are exercised by an integration spec using subprocesses.
- Charset recipe: ASCII alphabet encode to UTF-8, ISO-8859-1, Shift_JIS with reversible map.
- Disjoint ranges: map index 0...40 to 1..20 and 40..59 (reversible, no frequency dependency).
- Factory: Plain Ruby User, FactoryBot.build attribute overrides. Faker random generated
  from a PBT-generated seed on every case, restoring prior Faker::Config.random in ensure.
- Document seed replay, shrinking attributes not models, no DB writes, no random Faker defaults.

Completed: tests committed red c69ae26, implementation and dedicated CI added.
Verification: full rake 183 examples, 0 failures, Standard passes; optional bundle
FactoryBot/Faker 2 examples, 0 failures. Independent review clean after adding
exception-path RNG restoration coverage.
