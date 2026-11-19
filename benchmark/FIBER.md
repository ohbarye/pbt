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

## Scheduler-backed TCP IO experiment

The separate experiment in `benchmark/fiber_scheduler/experiment.rb` uses Async's
scheduler. Async is an optional benchmark dependency, not a dependency of pbt:

```sh
BUNDLE_GEMFILE=benchmark/fiber_scheduler/Gemfile bundle install
BUNDLE_GEMFILE=benchmark/fiber_scheduler/Gemfile bundle exec rspec benchmark/fiber_scheduler/spec
BUNDLE_GEMFILE=benchmark/fiber_scheduler/Gemfile bundle exec ruby benchmark/fiber_scheduler/experiment.rb
```

Parameters are `NUM_RUNS` (100), `CONCURRENCY` (10), `IO_DELAY` (0.01 seconds),
and `REPEATS` (5; use an odd number). Each mode gets a separate warmup. The timer
includes client socket creation, connection, reads, property calls and scheduler
startup/cleanup, but excludes gem loading, input generation and server startup.

A dedicated server thread accepts loopback TCP connections and independently delays
each `ok` response by 10ms. Clients perform a real blocking `Socket#read` through
`TCPSocket`, which Async makes cooperative. The three modes use the same seed-42
integer inputs and identical protocol: serial requests, serial requests wrapped in
bare Fibers, and batches of at most 10 concurrent Async tasks. Batches wait for all
members before starting the next batch; this is not a continuously filled pool.
The server records its peak number of pending responses to verify that IO waits
actually overlap; timing thresholds are deliberately absent from tests.

Local measurement: Ruby 4.0.9, Async 2.46.0, arm64 macOS, 100 cases, seed 42,
10ms per response, maximum concurrency 10, 5 repetitions after warmup:

```text
mode        elapsed seconds (all 5 samples)                  median seconds
sequential  1.232761 1.246074 1.233465 1.250332 1.226240       1.233465
bare Fiber  1.232813 1.231938 1.224650 1.241142 1.213324       1.231938
scheduler   0.124735 0.129789 0.130015 0.130826 0.128622       0.129789
```

Every sample completed 100 requests and produced the same input checksum, 47379.
Server peak pending responses were 1 for serial/bare Fiber and 10 for Scheduler
in every repetition. The Scheduler median was about 9.5 times faster than serial
for this intentionally wait-dominated workload. This demonstrates overlapping IO
waits, rather than CPU parallelism. It is not a general throughput guarantee;
loopback, synthetic delay, small payloads, batch size and machine load all matter.

The optional tests cover identical inputs and counts, bounded pending requests,
exception propagation, server-thread cleanup and refusing to replace an existing
caller-owned scheduler. Client and server sockets are closed in ensure blocks;
remaining batch tasks are stopped after failure. Async may log the expected failure
in the cleanup test. The benchmark owns its scheduler only when none is installed.
CI runs these optional tests separately on Ruby 3.3 and 4.0.

### Decision after both experiments

Keep the existing public workers for v1. The scheduled experiment calls generated
properties directly; it does not integrate with `Pbt.check`, its early-failure
ordering, cancellation policy, shrinking, reports or Ractor worker. The baseline
spec's report parity does not establish report parity for concurrent Async tasks.

Scheduler-backed execution can help IO-heavy properties, but adoption needs a
separate design for in-flight case cleanup, failure ordering, exception propagation,
shared fixture state, concurrency limits and scheduler ownership. A caller-installed
scheduler must not be replaced or closed by pbt. No public API or runtime dependency
is added by this experiment.

References: [Ruby Fiber scheduler interface](https://docs.ruby-lang.org/en/master/Fiber/Scheduler.html),
[Async](https://github.com/socketry/async).
