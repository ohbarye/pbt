# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/arbitrary/arbitrary_methods"
require_relative "pbt/check/runner_methods"
require_relative "pbt/check/property"
require_relative "pbt/check/configuration"

module Pbt
  class PropertyFailure < StandardError; end

  extend Arbitrary::ArbitraryMethods
  extend Check::RunnerMethods
  extend Check::ConfigurationMethods

  # @param args [Array<Pbt::Arbitrary>]
  # @param kwargs [Hash<Symbol->Pbt::Arbitrary>]
  # @return [Property]
  def self.property(*args, **kwargs, &predicate)
    arb = to_arbitrary(args, kwargs)
    Check::Property.new(arb, &predicate)
  end

  class << self
    private

    # Convert arguments to suitable arbitrary.
    # If multiple arguments are given, wrap them by tuple arbitrary.
    # If keyword arguments are given, wrap them by fixed hash arbitrary.
    # Else, return the single arbitrary.
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
