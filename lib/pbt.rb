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

  # @param arbs [Array<Pbt::Arbitrary>]
  # @return [Property]
  def self.property(*arbs, &predicate)
    arb = if arbs.size == 1
      arbs.first
    else
      # wrap by tuple arbitrary so that property class doesn't have to take care of an array
      tuple(*arbs)
    end
    Check::Property.new(arb, &predicate)
  end
end
