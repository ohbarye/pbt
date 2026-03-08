# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/arbitrary/arbitrary_methods"
require_relative "pbt/check/runner_methods"
require_relative "pbt/check/property"
require_relative "pbt/check/configuration"
require_relative "pbt/stateful/property"

module Pbt
  # Represents a property-based test failure.
  class PropertyFailure < StandardError; end

  # Represents an invalid configuration.
  class InvalidConfiguration < StandardError; end

  extend Arbitrary::ArbitraryMethods
  extend Check::RunnerMethods
  extend Check::ConfigurationMethods

  # Create a property-based test with arbitraries. To run the test, pass the returned value to `Pbt.assert` method.
  # Be aware that using both positional and keyword arguments is not supported.
  #
  # @example Basic usage
  #   Pbt.property(Pbt.integer) do |n|
  #     # your test code here
  #   end
  #
  # @example Use multiple arbitraries
  #   Pbt.property(Pbt.string, Pbt.symbol) do |str, sym|
  #     # your test code here
  #   end
  #
  # @example Use hash arbitraries
  #   Pbt.property(x: Pbt.integer, y: Pbt.integer) do |x, y|
  #     # your test code here
  #   end
  #
  # @param args [Array<Arbitrary>] Arbitraries to generate values. You can pass one or more arbitraries.
  # @param kwargs [Hash<Symbol,Arbitrary>] Arbitraries to generate values. You can pass arbitraries with keyword arguments.
  # @param predicate [Proc] Test code that receives generated values and runs the test.
  # @return [Property]
  def self.property(*args, **kwargs, &predicate)
    arb = to_arbitrary(args, kwargs)
    Check::Property.new(arb, &predicate)
  end

  # Create a stateful property-based test backed by a model and a SUT factory.
  # The returned object is compatible with `Pbt.assert` / `Pbt.check`.
  #
  # The model object is expected to provide:
  # - `initial_state`
  # - `commands(state)` -> Array of command objects
  #
  # Each command object is expected to provide:
  # - `name`
  # - `arguments` (an arbitrary) or `arguments(state)`
  # - `applicable?(state)` -> bool or `applicable?(state, args)` -> bool
  # - `next_state(state, args)`
  # - `run!(sut, args)` -> result
  # - `verify!(before_state:, after_state:, args:, result:, sut:)`
  #
  # @param model [Object]
  # @param sut [Proc] Factory proc that returns a fresh SUT per run.
  # @param max_steps [Integer]
  # @return [Pbt::Stateful::Property]
  def self.stateful(model:, sut:, max_steps: 20)
    Stateful::Property.new(model:, sut:, max_steps:)
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
        fixed_hash(kwargs)
      elsif args != [] && kwargs == {}
        # wrap by tuple arbitrary so that property class doesn't have to take care of an array
        (args.size == 1) ? args.first : tuple(*args)
      else
        raise ArgumentError, <<~MSG
          It's not supported to use both positional and keyword arguments at the same time.
          cf. https://www.ruby-lang.org/en/news/2019/12/12/separation-of-positional-and-keyword-arguments-in-ruby-3-0/
        MSG
      end
    end
  end
end
