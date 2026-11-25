# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/statistics"
require_relative "pbt/arbitrary/arbitrary_methods"
require_relative "pbt/check/runner_methods"
require_relative "pbt/check/property"
require_relative "pbt/check/configuration"
require_relative "pbt/stateful/property"

module Pbt
  # Represents a property-based test failure.
  class PropertyFailure < StandardError; end

  # Represents a property-based test failure caused by exceeding the skip budget via `Pbt.assume`.
  class TooManySkipsError < PropertyFailure; end

  # Internal control-flow exception raised by `Pbt.assume` when a precondition is not met.
  class PreconditionNotMet < StandardError; end

  # Represents an invalid configuration.
  class InvalidConfiguration < StandardError; end

  extend Arbitrary::ArbitraryMethods
  extend Check::RunnerMethods
  extend Check::ConfigurationMethods

  # Discard the current generated test case when `condition` is falsy.
  # Discarded cases do not count toward `num_runs` and are skipped during shrinking.
  # Exceeding `max_skips` fails the property with `Pbt::TooManySkipsError`.
  #
  # @param condition [Object]
  # @return [void]
  # @raise [Pbt::PreconditionNotMet]
  def self.assume(condition)
    raise PreconditionNotMet unless condition
  end

  # Create a property-based test with arbitraries. To run the test, pass the returned value to `Pbt.assert` or `Pbt.check`.
  # Predicates fail by raising an exception (including RSpec/Minitest assertions); returning `false` alone does not fail.
  # Be aware that using both positional and keyword arguments is not supported.
  #
  # @example Basic usage
  #   Pbt.property(Pbt.integer) do |n|
  #     # your test code here
  #   end
  #
  # @example Use multiple positional arbitraries
  #   Pbt.property(Pbt.ascii_string, Pbt.symbol) do |str, sym|
  #     # your test code here
  #   end
  #
  # @example Use keyword arbitraries (under default `worker: :none`)
  #   Pbt.property(x: Pbt.integer, y: Pbt.integer) do |x:, y:|
  #     # your test code here
  #   end
  #
  # @example Use keyword arbitraries with `worker: :ractor` (Ractor passes the Hash as a single argument)
  #   Pbt.property(x: Pbt.integer, y: Pbt.integer) do |h|
  #     # h[:x], h[:y]
  #   end
  #
  # @param args [Array<Arbitrary>] Arbitraries to generate values. You can pass one or more arbitraries.
  # @param kwargs [Hash<Symbol,Arbitrary>] Arbitraries to generate values. You can pass arbitraries with keyword arguments.
  # @param predicate [Proc] Test code that receives generated values and runs the test.
  # @return [Check::Property]
  def self.property(*args, **kwargs, &predicate)
    raise ArgumentError, "Pbt.property requires a predicate block" unless predicate

    arb = to_arbitrary(args, kwargs)
    Check::Property.new(
      arb,
      keyword_args: args.empty? && !kwargs.empty?,
      splat_args: args.size > 1,
      &predicate
    )
  end

  # Create a stateful property-based test using a yield-based model builder DSL.
  # The returned `Pbt::Stateful::Property` is compatible with `Pbt.assert`, `Pbt.check`,
  # `Pbt.statistics`, and `property.replay(run)`.
  #
  # @param max_steps [Integer] Maximum number of commands per generated run (default: 20).
  # @param min_steps [Integer] Target minimum number of commands per generated run (default: 1).
  #   A run may stop earlier if it reaches a terminal state where no command guard is truthy.
  # @param max_shrink_attempts [Integer] Total shrink attempt budget per failure (default: 1000).
  # @yieldparam m [Pbt::Stateful::SpecBuilder] Model builder for `initial_state`, `sut`/`teardown`/`around`, `command`, and `invariant`.
  # @return [Pbt::Stateful::Property]
  def self.stateful(max_steps: 20, min_steps: 1, max_shrink_attempts: 1_000)
    raise Stateful::InvalidSpec, "Pbt.stateful requires a block" unless block_given?

    builder = Stateful::SpecBuilder.new
    yield(builder)
    spec = builder.build
    Stateful::Property.new(
      spec: spec,
      max_steps: max_steps,
      min_steps: min_steps,
      max_shrink_attempts: max_shrink_attempts
    )
  end

  # Inspect an independent sample of generated values, optionally grouped by a classifier.
  # Values/labels used as Hash keys must not be mutated during or after sampling.
  # @return [Statistics] Counts, percentages and the seed used for replay.
  def self.statistics(arbitrary, num_runs: 100, seed: Random.new_seed, &classifier)
    Statistics.new(arbitrary, num_runs: num_runs, seed: seed, &classifier)
  end

  class << self
    private

    # Convert arguments to suitable arbitrary.
    # If multiple arguments are given, wrap them by tuple arbitrary.
    # If keyword arguments are given, wrap them by fixed hash arbitrary.
    # Else, return the single arbitrary.
    #
    # @param args [Array<Arbitrary>]
    # @param kwargs [Hash<Symbol,Arbitrary>]
    # @return [Arbitrary]
    # @raise [ArgumentError] When both positional and keyword arguments are given
    def to_arbitrary(args, kwargs)
      if args == [] && kwargs != {}
        validate_arbitraries!(kwargs.values)
        fixed_hash(kwargs)
      elsif args != [] && kwargs == {}
        validate_arbitraries!(args)
        # wrap by tuple arbitrary so that property class doesn't have to take care of an array
        (args.size == 1) ? args.first : tuple(*args)
      elsif args == [] && kwargs == {}
        raise ArgumentError, "Pbt.property requires at least one arbitrary"
      else
        raise ArgumentError, <<~MSG
          It's not supported to use both positional and keyword arguments at the same time.
          cf. https://www.ruby-lang.org/en/news/2019/12/12/separation-of-positional-and-keyword-arguments-in-ruby-3-0/
        MSG
      end
    end

    def validate_arbitraries!(arbs)
      arbs.each do |arb|
        unless arb.respond_to?(:generate) && arb.respond_to?(:shrink)
          raise ArgumentError, "Pbt.property expects arbitraries responding to generate and shrink, got #{arb.class}"
        end
      end
    end
  end
end
