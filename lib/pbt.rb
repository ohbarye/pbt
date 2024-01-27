# frozen_string_literal: true

require_relative "pbt/version"
require_relative "pbt/generator"
require_relative "pbt/runner"

module Pbt
  class CaseFailure < StandardError; end

  def self.forall(generator, &block)
    Runner.new(generator, &block).run
  end
end
