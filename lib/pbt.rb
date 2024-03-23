# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/arbitrary/arbitrary_methods"
require_relative "pbt/arbitrary/generator"
require_relative "pbt/check/runner_methods"
require_relative "pbt/check/property"
require_relative "pbt/check/configuration"

module Pbt
  class PropertyFailure < StandardError; end

  extend Arbitrary::ArbitraryMethods
  extend Check::RunnerMethods
  extend Check::ConfigurationMethods

  # @return [Property]
  def self.property(generator, &predicate)
    Check::Property.new(generator, &predicate)
  end
end
