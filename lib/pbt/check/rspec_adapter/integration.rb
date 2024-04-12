# frozen_string_literal: true

unless defined?(RSpec)
  raise InvalidConfigurationError, "You configured `experimental_ractor_rspec_integration: true` but RSpec is not loaded. Please use RSpec or set the config `false`."
end

require "pbt/check/rspec_adapter/predicate_block_inspector"
require "pbt/check/rspec_adapter/property_extension"

module Pbt
  module Check
    # @private
    module RSpecAdapter
      # This custom error contains RSpec matcher and message to handle Pbt's runner.
      # @private
      class ExpectationNotMet < StandardError
        attr_reader :matcher, :custom_message, :failure_message_method

        def initialize(msg, matcher, custom_message, failure_message_method)
          super(msg)
          @matcher = matcher
          @custom_message = custom_message
          @failure_message_method = failure_message_method
        end
      end
    end
  end
end

# `autoload` is not allowed in Ractor but RSpec uses autoload for matchers.
# We need to load them in advance in order to be able to use them in Ractor.
#
# e.g. Ractor raises... `be_a_kind_of': require by autoload on non-main Ractor is not supported (BeAKindOf) (Ractor::UnsafeError)
RSpec::Matchers::BuiltIn.constants.each { |c| Object.const_get("RSpec::Matchers::BuiltIn::#{c}") }

# TODO: preload more helpers like aggregate_failures.
# RSpec::Expectations.constants.each { |c| Object.const_get("RSpec::Expectations::#{c}") }
# The code above is not enough. Even if we run this code in advance, Ractor raises...
# in `failure_notifier': can not access non-shareable objects in constant RSpec::Support::DEFAULT_FAILURE_NOTIFIER by non-main ractor. (Ractor::IsolationError)

# CAUTION: This is a dirty hack! We need to override the original method to make it Ractor-safe.
RSpec::Expectations::ExpectationHelper.singleton_class.prepend(Module.new do
  def with_matcher(handler, matcher, message)
    check_message(message)
    matcher = modern_matcher_from(matcher)
    yield matcher
  ensure
    # The original method is not Ractor-safe unless stopping assigning these class variables.
    if Ractor.current == Ractor.main
      ::RSpec::Matchers.last_expectation_handler = handler
      ::RSpec::Matchers.last_matcher = matcher
    end
  end

  def handle_failure(matcher, message, failure_message_method)
    # This method is not Ractor-safe. RSpec::Support::ObjectFormatter.default_instance assigns class variables.
    # If this method is called in non-main-Ractor, it raises a custom error and let it handle in the main Ractor.
    if Ractor.current != Ractor.main
      raise Pbt::Check::RSpecAdapter::ExpectationNotMet.new(nil, matcher, message, failure_message_method)
    end

    super
  end
end)
