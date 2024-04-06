# Property-Based Testing in Ruby

⚠️ This gem is currently in the proof of concept phase. It's experimental and not production quality for now!

A property-based testing tool for Ruby, utilizing Ractor for parallelizing test cases.

## Installation

```shell
$ gem install pbt
```

If you want to use concurrency methods other than Ractor (`process`, `thread`), you need to install [parallel](https://github.com/grosser/parallel) gem as well.

```shell
$ gem install parallel
```

## Usage

```ruby
# Let's say you have a method that returns just a multiplicative inverse.
def multiplicative_inverse(number)
  Rational(1, number)
end

RSpec.describe Pbt do
  it "works" do
    Pbt.assert do
      # The given block is executed 100 times with different random numbers.
      # Besides, the block runs in parallel by Ractor.
      Pbt.property(Pbt.integer) do |number|
        result = multiplicative_inverse(number)
        raise "Result should be the multiplicative inverse of the number" if result * number != 1
      end
    end
    
    # If the function has a bug, the test fails with a counterexample.
    # For example, the multiplicative_inverse method doesn't work for 0 regardless of the behavior is intended or not.
    #
    # Pbt::PropertyFailure:
    #   Property failed after 23 test(s)
    #   { seed: 11001296583699917659214176011685741769 }
    #   Counterexample: 0
    #   Shrunk 3 time(s)
    #   Got ZeroDivisionError: divided by 0
  end
end
```

### Arbitrary

TBA

### Configuration

TBA

### Concurrent methods

Pbt supports 3 concurrency methods and 1 sequential one. You can choose one of them by setting the `concurrency_method` option.

#### Ractor

```ruby
Pbt.assert(params: { concurrency_method: :ractor }) do
  Pbt.property(Pbt.integer) do |number|
    # ...
  end
end
```

#### Process

```ruby
Pbt.assert(params: { concurrency_method: :process }) do
  Pbt.property(Pbt.integer) do |number|
    # ...
  end
end
```

#### Thread

```ruby
Pbt.assert(params: { concurrency_method: :thread }) do
  Pbt.property(Pbt.integer) do |number|
    # ...
  end
end
```

#### None

```ruby
Pbt.assert(params: { concurrency_method: :none }) do
  Pbt.property(Pbt.integer) do |number|
    # ...
  end
end
```

## TODOs

- [x] Enable to combine arbitraries (e.g. `Pbt.array(Pbt.integer)`)
- [x] Support shrinking
- [x] Implement basic arbitraries
  - https://proper-testing.github.io/apidocs/
  - https://fast-check.dev/docs/core-blocks/arbitraries/
- [x] Support multiple concurrency methods
  - [x] Ractor
  - [x] Process
  - [x] Thread
  - [x] None (Run tests sequentially)
- [ ] Rich report like verbose mode
- [ ] Allow to use assertions provided by RSpec etc. if possible
  - It'd be so hard to pass assertions like `expect`, `assert` to a Ractor. But it's worth trying at least for `process`, `thread` concurrency methods.
- [ ] Documentation
  - [ ] Add better examples
  - [ ] Arbitrary usage
  - [ ] Configuration

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Lint

```shell
bundle exec rake standard:fix
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ohbarye/pbt. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/pbt/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Pbt project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ohbarye/pbt/blob/master/CODE_OF_CONDUCT.md).
