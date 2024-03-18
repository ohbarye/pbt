# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/generator"
require_relative "pbt/runner"
require_relative "pbt/configuration"

module Pbt
  class CaseFailure < StandardError; end

  @properties = []

  def self.property(name, &)
    configure unless const_defined?(:Configuration)
    @properties << if Configuration.use_ractor
      Ractor.new(name: name, &)
    else
      yield
    end
  end

  def self.wait_for_all_properties
    @properties.each(&:take) if Configuration.use_ractor
    @properties = []
  end

  def self.forall(generator, config: {}, &)
    config = Configuration.to_h.merge(config.to_h)
    Runner.new(generator, config:, &).run
  end
end
