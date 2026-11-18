# Fiber predicate experiment

Run from the repository root:

```sh
bundle exec ruby benchmark/fiber_experiment.rb
NUM_RUNS=1000 bundle exec ruby benchmark/fiber_experiment.rb
```

This compares the normal sequential runner with the same runner wrapping each
predicate call in a newly created Fiber. Both use seed 42, the same number of
cases, and the same CPU / blocking-sleep predicates. The script checks successful
case counts and measures wall time with a monotonic clock. It installs no scheduler.
The integration spec separately compares success counts and failure/shrink reports.

## Decision for v1

Keep `worker: :none` as the default and `:ractor` as the existing opt-in worker.
The bare-Fiber experiment is complete; it does not justify a new public worker.
A Fiber per case adds allocation/context-switching work, while blocking sleep
still blocks its thread. This is a baseline experiment, not a benchmark of a
scheduler-backed asynchronous worker or evidence against all Fiber designs.

A local smoke run on Ruby 4.0.9 (arm64 macOS), 100 cases, seed 42 produced:

```text
cpu sequential             0.001758 seconds
cpu fiber                  0.002105 seconds
blocking_sleep sequential  0.126800 seconds
blocking_sleep fiber       0.128960 seconds
```

These short timings are illustrative and noisy, not performance guarantees.
Re-run on the target Ruby/platform with representative workloads before drawing
performance conclusions. CPU parallelism is not provided by these same-thread Fibers.

A future scheduler-backed experiment needs a concrete IO-bound use case and explicit
limits on concurrency, in-flight case cleanup after failure, exception propagation,
shared fixture state, and scheduler ownership. A caller-installed scheduler should
not be replaced or closed by pbt. Ruby's scheduler interface supports nonblocking IO,
but providing that lifecycle is a separate design decision.

Reference: [Ruby Fiber scheduler interface](https://docs.ruby-lang.org/en/master/Fiber/Scheduler.html).
