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

- macOS 14.4.1, Apple M1 Pro 10 cores (8 performance and 2 efficiency)
- ruby 3.3.1 (2024-04-23 revision c56cd86388) +MN [arm64-darwin23]
- pbt commit hash ecaecceb73a171042e52dbad25074f4f7dcfd55a

---

### Benchmark success:simple

This runs a script that does not do any IO or CPU bound work.

```
ruby benchmark/success_simple.rb
ruby 3.3.1 (2024-04-23 revision c56cd86388) +MN [arm64-darwin23]
Warming up --------------------------------------
              ractor    21.000 i/100ms
             process     3.000 i/100ms
              thread   111.000 i/100ms
                none   172.000 i/100ms
Calculating -------------------------------------
              ractor     73.709 (± 8.1%) i/s -    378.000 in   5.166176s
             process      1.868 (± 0.0%) i/s -     12.000 in   6.423704s
              thread      1.028k (±33.4%) i/s -      4.773k in   5.123614s
                none      1.534k (±24.4%) i/s -      7.224k in   5.037993s
```

### Benchmark success:cpu_bound

This runs a script that does CPU bound work.

```
ruby benchmark/success_cpu_bound.rb
ruby 3.3.1 (2024-04-23 revision c56cd86388) +MN [arm64-darwin23]
Warming up --------------------------------------
              ractor     3.000 i/100ms
             process     2.000 i/100ms
              thread     1.000 i/100ms
                none     1.000 i/100ms
Calculating -------------------------------------
              ractor     39.273 (± 2.5%) i/s -    198.000 in   5.042910s
             process     20.631 (± 4.8%) i/s -    104.000 in   5.068093s
              thread      7.657 (± 0.0%) i/s -     39.000 in   5.096493s
                none      7.765 (± 0.0%) i/s -     39.000 in   5.022829s
```

### Benchmark success:io_bound

This runs a script that does IO bound work.

```
ruby benchmark/success_io_bound.rb
ruby 3.3.1 (2024-04-23 revision c56cd86388) +MN [arm64-darwin23]
Warming up --------------------------------------
              ractor    11.000 i/100ms
             process     2.000 i/100ms
              thread    15.000 i/100ms
                none    20.000 i/100ms
Calculating -------------------------------------
              ractor     53.841 (± 3.7%) i/s -    275.000 in   5.114164s
             process     10.077 (± 0.0%) i/s -     52.000 in   5.166346s
              thread    130.750 (±16.8%) i/s -    645.000 in   5.057727s
                none    151.102 (± 4.0%) i/s -    760.000 in   5.038146s
```

### Benchmark failure:simple

This runs a script that fails and shrink happens.

```
ruby benchmark/failure_simple.rb
ruby 3.3.1 (2024-04-23 revision c56cd86388) +MN [arm64-darwin23]
Warming up --------------------------------------
              ractor     7.000 i/100ms
             process     1.000 i/100ms
              thread    14.000 i/100ms
                none   264.000 i/100ms
Calculating -------------------------------------
              ractor     12.466 (± 8.0%) i/s -     63.000 in   5.080393s
             process      0.059 (± 0.0%) i/s -      1.000 in  17.091278s
              thread    110.228 (±20.0%) i/s -    532.000 in   5.054091s
                none      2.425k (±23.1%) i/s -     11.616k in   5.053378s
```
