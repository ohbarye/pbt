# Benchmark of concurrency methods

This benchmark compares the performance of different concurrency methods that `Pbt` provides.

## Usage

```shell
bundle exec rake benchmark:all
```

## Diagnosis

Based on benchmark results, it can be said that for most test cases, which are neither I/O-bound nor CPU-bound, concurrency is unnecessary. The overhead of implementing multithreading or multiprocessing outweighs the benefits. For the majority of users, the best strategy is to use `worker: :none`.

However, when the test subject involves CPU-bound processes, `worker: :ractor` emerges as the champion. That's because threads across Ractors run in parallel. It outperforms multithreading, which due to the GVL, only offers performance equivalent to serial processing, and it does so without the overhead associated with multiprocessing.

Interestingly, both multi-process (`worker: :process`) and multi-thread (`worker: :thread`) failed to emerge as the champion in any case.

## Benchmarks

The following benchmarks are the results of running the benchmark suite.

- macOS 13.3.1, Apple M1 Pro 10 cores (8 performance and 2 efficiency)
- ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin22]
- pbt commit hash 6582b27105ef5e92197b3f52f9c7cf78d731e1e2

---

### Benchmark success:simple

This runs a script that does not do any IO or CPU bound work.

ruby benchmark/success_simple.rb
ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin22]
Warming up --------------------------------------
ractor    20.000 i/100ms
process     3.000 i/100ms
thread   126.000 i/100ms
none   668.000 i/100ms
Calculating -------------------------------------
ractor    173.918 (±11.5%) i/s -    880.000 in   5.129007s
process     28.861 (± 3.5%) i/s -    147.000 in   5.100393s
thread      1.130k (± 5.5%) i/s -      5.670k in   5.031552s
none      6.534k (± 2.3%) i/s -     32.732k in   5.011885s

### Benchmark success:cpu_bound

This runs a script that does CPU bound work.

ruby benchmark/success_cpu_bound.rb
Call tarai function with(9, 4, 0)

ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin22]
Warming up --------------------------------------
ractor     3.000 i/100ms
process     2.000 i/100ms
thread     1.000 i/100ms
none     1.000 i/100ms
Calculating -------------------------------------
ractor     32.788 (± 6.1%) i/s -    165.000 in   5.057492s
process     22.098 (± 4.5%) i/s -    112.000 in   5.080410s
thread      7.439 (± 0.0%) i/s -     38.000 in   5.108195s
none      7.494 (± 0.0%) i/s -     38.000 in   5.070547s

### Benchmark success:io_bound

This runs a script that does IO bound work.

ruby benchmark/success_io_bound.rb
ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin22]
Warming up --------------------------------------
ractor    11.000 i/100ms
process     3.000 i/100ms
thread    17.000 i/100ms
none    22.000 i/100ms
Calculating -------------------------------------
ractor     82.488 (±14.5%) i/s -    407.000 in   5.054559s
process     35.403 (± 5.6%) i/s -    177.000 in   5.013818s
thread    143.022 (± 7.7%) i/s -    714.000 in   5.021129s
none    223.252 (± 9.0%) i/s -      1.122k in   5.071176s

### Benchmark failure:simple

This runs a script that fails and shrink happens.

ruby benchmark/failure_simple.rb
ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [arm64-darwin22]
Warming up --------------------------------------
ractor     6.000 i/100ms
process     1.000 i/100ms
thread     9.000 i/100ms
none   815.000 i/100ms
Calculating -------------------------------------
ractor     62.770 (±15.9%) i/s -    306.000 in   5.009858s
process      1.783 (± 0.0%) i/s -      9.000 in   5.049606s
thread     85.218 (± 9.4%) i/s -    423.000 in   5.007178s
none      5.387k (± 3.3%) i/s -     27.710k in   5.149867s
