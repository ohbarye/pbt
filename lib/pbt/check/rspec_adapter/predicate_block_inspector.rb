# frozen_string_literal: true

begin
  # Use prism to get user-defined block code.
  require "prism"
rescue LoadError
  raise InvalidConfiguration,
    "Prism gem (https://github.com/grosser/parallel) is required to use worker `:rator` and `:experimental_ractor_rspec_integration`. Please add `gem 'parallel'` to your Gemfile."
end

module Pbt
  module Check
    module RSpecAdapter
      # This class is used to get user-defined block code.
      # If a user defines code like below:
      #
      #   Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
      #     x > 0 && y > 0
      #   end
      #
      #   inspector.method_params #=> "x, y"
      #   inspector.method_body   #=> "x > 0 && y > 0"
      #
      # @private
      # @!attribute [r] method_body
      # @!attribute [r] method_params
      class PredicateBlockInspector < Prism::Visitor
        attr_reader :method_body, :method_params

        def initialize(line)
          @line = line
          @method_body = nil
          super()
        end

        def visit_call_node(node)
          if node.name == :property && node.block.opening_loc.start_line == @line
            @method_params = node.block.parameters.parameters.slice
            @method_body = node.block.body.slice
          end

          super
        end
      end
    end
  end
end
