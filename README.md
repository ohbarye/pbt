# Property-Based Testing in Ruby

⚠️ This gem is currently in the proof of concept phase. It's experimental and not production quality for now!

A property-based testing tool for Ruby, utilizing Ractor for parallelizing test cases.

## Installation

Install the gem and add to the application's Gemfile by executing:

```shell
$ bundle add pbt
```

If bundler is not being used to manage dependencies, install the gem by executing:

```shell
$ gem install pbt
```

## Usage

```ruby
# Let's say you have a method that returns just a reciprocal number.
def reciprocal(number)
  Rational(1, number)
end

RSpec.describe Pbt do
  it "works" do
    # The given block is executed 100 times with different random numbers.
    # Besides, the block runs in parallel by Ractor.
    Pbt.forall(Pbt::Generator.integer) do |number|
      result = reciprocal(number)
      raise "Result should be even number" if result * number == 0
    end
    
    # If the function has a bug, the test fails with a counterexample.
    # For example, the reciprocal method doesn't work for 0 regardless of the behavior is intended or not.
    # 
    # Pbt::CaseFailure:
    #   ZeroDivisionError:
    #   Failed on:
    #            0
  end
end
```

## TODOs

- [ ] More generators
  - https://proper-testing.github.io/apidocs/
- [ ] Enable to combine generators
  - e.g. `Pbt::Generator.list(Pbt::Generator.integer)`
- [ ] More sophisticated syntax for property-based testing
  - e.g. `forall(integer) { |number| ... }` (Omit `Pbt` module)
- [ ] Support for shrinking
- [ ] Allow to use assertions
  - It's hard to pass assertions like `expect`, `assert` to a Ractor?

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pbt. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/pbt/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Pbt project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pbt/blob/master/CODE_OF_CONDUCT.md).
