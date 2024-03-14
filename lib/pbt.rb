# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/generator"
require_relative "pbt/runner"

module Pbt
  class CaseFailure < StandardError; end

  @properties = []

  def self.property(name, &)
    @properties << Ractor.new(name: name, &)
  end

  def self.wait_for_all_properties
    @properties.each(&:take)
    @properties = []
  end

  def self.forall(generator, &)
    Runner.new(generator, &).run
  end
end
