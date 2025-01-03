# Property-Based Testing in Ruby

[![Gem Version](https://badge.fury.io/rb/pbt.svg)](https://rubygems.org/gems/pbt)
[![Build Status](https://github.com/ohbarye/pbt/actions/workflows/main.yml/badge.svg)](https://github.com/ohbarye/pbt/actions/workflows/main.yml)
[![RubyDoc](https://img.shields.io/badge/%F0%9F%93%9ARubyDoc-documentation-informational.svg)](https://www.rubydoc.info/gems/pbt)

A property-based testing tool for Ruby with experimental features that allow you to run test cases in parallel.

PBT stands for Property-Based Testing.

As for the results of the parallelization experiment, please refer the talk at RubyKaigi 2024: [Unlocking Potential of Property Based Testing with Ractor](https://rubykaigi.org/2024/presentations/ohbarye.html).

## What's Property-Based Testing?

Property-Based Testing is a testing methodology that focuses on the properties a system should always satisfy, rather than checking individual examples. Instead of writing tests for predefined inputs and outputs, PBT allows you to specify the general characteristics that your code should adhere to and then automatically generates a wide range of inputs to verify these properties.

The key benefits of property-based testing include the ability to cover more edge cases and the potential to discover bugs that traditional example-based tests might miss. It's particularly useful for identifying unexpected behaviors in your code by testing it against a vast set of inputs, including those you might not have considered.

For a more in-depth understanding of Property-Based Testing, please refer to external resources.

- Original ideas
  - [Property-based testing of privileged programs](https://ieeexplore.ieee.org/document/367311) (1994)
  - [Property-based testing: a new approach to testing for assurance](https://dl.acm.org/doi/abs/10.1145/263244.263267) (1997)
  - [QuickCheck: a lightweight tool for random testing of Haskell programs](https://dl.acm.org/doi/10.1145/351240.351266) (2000)
- Rather new introductory resources
  - Fred Hebert's book [Property-Based Testing With PropEr, Erlang and Elixir](https://propertesting.com/).
  - [fast-check - Why Property-Based?](https://fast-check.dev/docs/introduction/why-property-based/)

## Installation

Add this line to your application's Gemfile and run `bundle install`.

```ruby
gem 'pbt'
```

Off course you can install with `gem intstall pbt`.

## Basic Usage

### Simple property

```ruby
# Let's say you have your own sort method.
def sort(array)
  return array if array.size <= 2 # Here's a bug! It should be 1.
  pivot, *rest = array
  left, right = rest.partition { |n| n <= pivot }
  sort(left) + [pivot] + sort(right)
end

Pbt.assert do
  # The given block is executed 100 times with different arrays with random numbers.
  # Besides, if you set `worker: :ractor` option to `assert` method, it runs in parallel using Ractor.
  Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
    result = sort(numbers)
    result.each_cons(2) do |x, y|
      raise "Sort algorithm is wrong." unless x <= y
    end
  end
end

# If the method has a bug, the test fails and it reports a minimum counterexample.
# For example, the sort method doesn't work for [0, -1].
#
# Pbt::PropertyFailure:
#   Property failed after 23 test(s)
#   seed: 43738985293126714007411539287084402325
#   counterexample: [0, -1]
#   Shrunk 40 time(s)
#   Got RuntimeError: Sort algorithm is wrong.
```

### Explain The Snippet

The above snippet is very simple but contains the basic components.

#### Runner

`Pbt.assert` is the runner. The runner interprets and executes the given property. `Pbt.assert` takes a property and runs it multiple times. If the property fails, it tries to shrink the input that caused the failure.

#### Property

The snippet above declared a property by calling `Pbt.property`. The property describes the following:

1. What the user wants to evaluate. This corresponds to the block (let's call this `predicate`) enclosed by `do` `end`
2. How to generate inputs for the predicate — using `Arbitrary`

The `predicate` block is a function that directly asserts, taking values generated by `Arbitrary` as input.

#### Arbitrary

Arbitrary generates random values. It is also responsible for shrinking those values if asked to shrink a failed value as input.

Here, we used only one type of arbitrary, `Pbt.integer`. There are many other built-in arbitraries, and you can create a variety of inputs by combining existing ones.

#### Shrink

In PBT, If a test fails, it attempts to shrink the case that caused the failure into a form that is easier for humans to understand.
In other words, instead of stopping the test itself the first time it fails and reporting the failed value, it tries to find the minimal value that causes the error.

When there is a test that fails when given an even number, a counterexample of `[0, -1]` is simpler and easier to understand than any complex example like `[-897860, -930517, 577817, -16302, 310864, 856411, -304517, 86613, -78231]`.

### Arbitrary

There are many built-in arbitraries in `Pbt`. You can use them to generate random values for your tests. Here are some representative arbitraries.

#### Primitives

```ruby
rng = Random.new

Pbt.integer.generate(rng)                  # => 42
Pbt.integer(min: -1, max: 8).generate(rng) # => Integer between -1 and 8

Pbt.symbol.generate(rng)                   # => :atq

Pbt.ascii_char.generate(rng)               # => "a"
Pbt.ascii_string.generate(rng)             # => "aagjZfao"

Pbt.boolean.generate(rng)                  # => true or false
Pbt.constant(42).generate(rng)             # => 42 always
```

#### Composites

```ruby
rng = Random.new

Pbt.array(Pbt.integer).generate(rng)                        # => [121, -13141, 9825]
Pbt.array(Pbt.integer, max: 1, empty: true).generate(rng)   # => [] or [42] etc.

Pbt.tuple(Pbt.symbol, Pbt.integer).generate(rng)            # => [:atq, 42]

Pbt.fixed_hash(x: Pbt.symbol, y: Pbt.integer).generate(rng) # => {x: :atq, y: 42}
Pbt.hash(Pbt.symbol, Pbt.integer).generate(rng)             # => {atq: 121, ygab: -1142}

Pbt.one_of(:a, 1, 0.1).generate(rng)                        # => :a or 1 or 0.1
````

See [ArbitraryMethods](https://github.com/ohbarye/pbt/blob/main/lib/pbt/arbitrary/arbitrary_methods.rb) module for more details.

## What if property-based tests fail?

Once a test fails it's time to debug. `Pbt` provides some features to help you debug.

### How to reproduce

When a test fails, you'll see a message like below.

```text
Pbt::PropertyFailure:
  Property failed after 23 test(s)
  seed: 43738985293126714007411539287084402325
  counterexample: [0, -1]
  Shrunk 40 time(s)
  Got RuntimeError: Sort algorithm is wrong.
  # and backtraces
```

You can reproduce the failure by passing the seed to `Pbt.assert`.

```ruby
Pbt.assert(seed: 43738985293126714007411539287084402325) do
  Pbt.property(Pbt.array(Pbt.integer)) do |number|
    # your test
  end
end
```

### Verbose mode

You may want to know which values pass and which values fail. You can enable verbose mode by passing `verbose: true` to `Pbt.assert`.

```ruby
Pbt.assert(verbose: true) do
  Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
    # your failed test
  end
end
```

The verbose mode prints the results of each tested values.

```text
Encountered failures were:
- [-897860, -930517, 577817, -16302, 310864, 856411, -304517, 86613, -78231]
- [310864, 856411, -304517, 86613, -78231]
- [-304517, 86613, -78231]
(snipped for README)
- [0, -3]
- [0, -2]
- [0, -1]

Execution summary:
. × [-897860, -930517, 577817, -16302, 310864, 856411, -304517, 86613, -78231]
. . √ [-897860, -930517, 577817, -16302, 310864]
. . √ [-930517, 577817, -16302, 310864, 856411]
. . √ [577817, -16302, 310864, 856411, -304517]
. . √ [-16302, 310864, 856411, -304517, 86613]
. . × [310864, 856411, -304517, 86613, -78231]
(snipped for README)
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . √ [-2]
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . √ []
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . × [0, -1]
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . √ [0]
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . √ [-1]
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . √ []
. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . √ [0, 0]
```

## Configuration

You can configure `Pbt` by calling `Pbt.configure` before running tests.

```ruby
Pbt.configure do |config|
  # Whether to print verbose output. Default is `false`.
  config.verbose = false

  # The concurrency method to use. `:ractor` and `:none` are supported. Default is `:none`.
  config.worker = :none

  # The number of runs to perform. Default is `100`.
  config.num_runs = 100

  # The seed to use for random number generation.
  # It's useful to reproduce failed test with the seed you'd pick up from failure messages. Default is a random seed.
  config.seed = 42

  # Whether to report exceptions in threads.
  # It's useful to suppress error logs on Ractor that reports many errors. Default is `false`.
  config.thread_report_on_exception = false
end
```

Or, you can pass the configuration to `Pbt.assert` as an argument.

```ruby
Pbt.assert(num_runs: 100, seed: 42) do
  # ...
end
```

## Concurrency methods

One of the key features of `Pbt` is its ability to rapidly execute test cases in parallel or concurrently, using a large number of values (by default, `100`) generated by `Arbitrary`.

For concurrent processing, you can specify `:ractor` using the `worker` option. Alternatively, choose `:none` for serial execution.

Be aware that the performance of each method depends on the test subject. For example, if the test subject is CPU-bound, `:ractor` may be the best choice. Otherwise, `:none` shall be the best choice for most cases. See [benchmarks](benchmark/README.md).

### Ractor

`:ractor` worker is useful for test cases that are CPU-bound. But it's experimental and has some limitations as described below. If you encounter any issues due to those limitations, consider falling back to `:none`.

```ruby
Pbt.assert(worker: :ractor) do
  Pbt.property(Pbt.integer) do |n|
    # ...
  end
end
```

#### Limitation

Please note that Ractor support is an experimental feature of this gem. Due to Ractor's limitations, you may encounter some issues when using it.

For example, you cannot access anything out of block.

```ruby
a = 1

Pbt.assert(worker: :ractor) do
  Pbt.property(Pbt.integer) do |n|
    # You cannot access `a` here because this block is executed in a Ractor and it doesn't allow implicit sharing of objects.
    a + n # => Ractor::RemoteError (can not share object between ractors)
  end
end
```

You cannot use any methods provided by test frameworks like `expect` or `assert` because they are not available in a Ractor.

```ruby
it do
  Pbt.assert(worker: :ractor) do
    Pbt.property(Pbt.integer) do |n|
      # This is not possible because `self` if a Ractor here.
      expect(n).to be_an(Integer) # => Ractor::RemoteError (cause by NoMethodError for `expect` or `be_an`)
    end
  end
end
```

### None

For most cases, `:none` is the best choice. It runs tests sequentially but most test cases finishes within a reasonable time.

```ruby
Pbt.assert(worker: :none) do
  Pbt.property(Pbt.integer) do |n|
    # ...
  end
end
```

## TODOs

Once this project finishes the following, we will release v1.0.0.

- [x] Implement basic primitive arbitraries
- [x] Implement composite arbitraries
- [x] Support shrinking
- [x] Support multiple concurrency methods
  - [x] Ractor
  - [x] Process (dropped)
  - [x] Thread (dropped)
  - [x] None (Run tests sequentially)
- [x] Documentation
  - [x] Add better examples
  - [x] Arbitrary usage
  - [x] Configuration
- [x] Benchmark
- [x] Rich report by verbose mode
- [x] (Partially) Allow to use expectations and matchers provided by test framework in Ractor. (dropped)
  - It'd be so hard to pass assertions like `expect`, `assert` to a Ractor.
- [ ] Implement frequency arbitrary
- [ ] Statistics feature to aggregate generated values
- [ ] Decide DSL
- [ ] Try Fiber
- [ ] Stateful property-based testing

## Development

### Setup

```shell
bin/setup
bundle exec rake # Run tests and lint at once
```

### Test

```shell
bundle exec rspec
```

### Lint

```shell
bundle exec rake standard:fix
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ohbarye/pbt. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ohbarye/pbt/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

This project draws a lot of inspiration from other testing tools, namely

- [fast-check](https://fast-check.dev/)
- [Loupe](https://github.com/vinistock/loupe)
- [RSpec](https://github.com/rspec/rspec)
- [Minitest](https://github.com/seattlerb/minitest)
- [Parallel](https://github.com/grosser/parallel)
- [PropCheck for Ruby](https://github.com/Qqwy/ruby-prop_check)
- [PropCheck for Elixir](https://github.com/alfert/propcheck)

## Code of Conduct

Everyone interacting in the Pbt project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ohbarye/pbt/blob/master/CODE_OF_CONDUCT.md).
