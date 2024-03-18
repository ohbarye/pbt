# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/property"
require_relative "pbt/generator"
require_relative "pbt/runner"
require_relative "pbt/configuration"

module Pbt
  class CaseFailure < StandardError; end

  @properties = []

  def self.property(name, config: {}, &)
    configure unless const_defined?(:Configuration)
    config = Configuration.to_h.merge(config.to_h)
    @properties << Property.new(name, config:, &)
  end

  def self.wait_for_all_properties
    @properties.each(&:check)
    @properties = []
  end

  def self.forall(generator, config: {}, &)
    config = Configuration.to_h.merge(config.to_h)
    Runner.new(generator, config:, &).run
  end
end
