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

  require "prism"
  class BlockInspector < Prism::Visitor
    attr_reader :proc_str
    def initialize(line)
      @line = line
      @proc_str = nil
      super()
    end

    def visit_call_node(node)
      if node.name == :property && node.block.opening_loc.start_line == @line
        # Extract the block content
        # e.g.
        # "do |n|\n          raise unless n.is_a?(Integer)\n        end"
        @proc_str = "(Proc.new " + node.block.slice + ")"
      end

      super
    end
  end

  # @param args [Array<Pbt::Arbitrary>]
  # @param kwargs [Hash<Symbol->Pbt::Arbitrary>]
  # @return [Property]
  def self.property(ex, *args, **kwargs, &predicate)
    # This code reproduces predicate block's content as String
    file, line = predicate.source_location
    res = Prism.parse_file(file)
    foo = BlockInspector.new(line)
    res.value.statements.accept(foo)
    ps = foo.proc_str

    # This works
    # Get the object_id of the example instance and get the instance by the id
    id = ex.object_id
    pr1 = ObjectSpace._id2ref(id).instance_eval ps
    pr1.call(1)

    # This doesn't work. We need to create an example instance in Ractor block.
    r = Ractor.new(id, ps) do |id, ps|
      # If we can run the proc as if it's in a RSpec example instance
      # we can use `expect`, `be`, `raise_error`, etc.
      pr2 = ObjectSpace._id2ref(id).instance_eval ps
      pr2.call(1)
    end

    begin
      r.take
    rescue => e
      # --- Caused by: ---
      # RangeError:
      #   "3400" is id of the unshareable object on multi-ractor
      #   ./lib/pbt.rb:49:in `_id2ref'
      raise e.cause
    end

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
