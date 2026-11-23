# frozen_string_literal: true

require "pbt/arbitrary/sample"

module Pbt
  module Arbitrary
    class EmptyDomainError < ArgumentError; end
    class FilterExhaustedError < StandardError; end

    # Abstract class for generating random values on type `T`.
    #
    # @abstract
    class Arbitrary
      # Generate a value of type `T`, based on the provided random number generator.
      #
      # @abstract
      # @param rng [Random] Random number generator. Defaults to a new Random instance.
      # @return [Object] Random value of type `T`.
      def generate(rng = Random.new)
        raise NotImplementedError
      end

      # Shrink a value of type `T`.
      # Must never be called with possibly invalid values.
      #
      # @abstract
      # @param current [Object]
      # @return [Enumerator<Object>]
      def shrink(current)
        raise NotImplementedError
      end

      # Normalize an arbitrary's 3-valued `cover?` result to `true`, `false`, or `nil`.
      #
      # @private
      def self.cover_result(arbitrary, value)
        return nil unless arbitrary.respond_to?(:cover?)

        result = arbitrary.cover?(value)
        (result == true || result == false) ? result : nil
      end

      # Check whether `value` belongs to this arbitrary's domain.
      # Returns `true` if confirmed inside, `false` if confirmed outside,
      # or `nil` if membership cannot be determined reliably (e.g. custom arbitraries).
      #
      # @param _value [Object]
      # @return [Boolean, nil]
      def cover?(_value)
        nil
      end

      # Generate a value together with lazy shrinking provenance.
      # @return [Sample]
      def sample(rng = Random.new)
        Sample.from_value(self, generate(rng))
      end

      # Whether property execution must retain a per-value shrink tree.
      # @private
      def contextual?
        false
      end

      # Create another arbitrary by applying `mapper` (or a block) value by value.
      # When `unmapper` is omitted, shrinking still works in `Pbt.property` and `sample`
      # by preserving the underlying arbitrary's shrink tree.
      #
      # @example Block form (no unmapper required)
      #   Pbt.integer.map { |n| n.to_s }
      #
      # @example Explicit mapper and unmapper (also supports bare `#shrink`)
      #   Pbt.integer.map(->(n) { n.to_s }, ->(s) { s.to_i })
      #
      # @param mapper [Proc, nil] Proc to map generated values.
      # @param unmapper [Proc, nil] Optional proc to unmap generated values for bare `#shrink`.
      # @return [MapArbitrary] New arbitrary with mapped elements
      def map(mapper = nil, unmapper = nil, &block)
        if mapper && block
          raise ArgumentError, "map accepts either a mapper argument or a block, not both"
        end

        resolved_mapper = mapper || block
        unless resolved_mapper.respond_to?(:call)
          raise ArgumentError, "map requires a callable mapper or a block"
        end

        if !unmapper.nil? && !unmapper.respond_to?(:call)
          raise ArgumentError, "unmapper must be callable or nil"
        end

        MapArbitrary.new(self, resolved_mapper, unmapper)
      end

      # Create another arbitrary by feeding each generated value into `binder` (or a block)
      # to produce a dependent arbitrary. Shrinking works in `Pbt.property`, `Pbt.stateful`,
      # and `sample` by shrinking both the outer value and the dependent inner value.
      #
      # @example Block form
      #   Pbt.integer(min: 0, max: 100).flat_map { |min| Pbt.integer(min: min, max: 100).map { |max| [min, max] } }
      #
      # @param binder [#call, nil] Callable returning an arbitrary for each generated value.
      # @return [BindArbitrary] New dependent arbitrary.
      def bind(binder = nil, &block)
        if binder && block
          raise ArgumentError, "bind accepts either a binder argument or a block, not both"
        end

        resolved_binder = binder || block
        unless resolved_binder.respond_to?(:call)
          raise ArgumentError, "bind requires a callable binder or a block"
        end

        BindArbitrary.new(self, resolved_binder)
      end
      alias_method :flat_map, :bind

      # Create another arbitrary by filtering values against `refinement`.
      # All the values produced by the resulting arbitrary satisfy `!!refinement(value) == true`.
      #
      # Be aware that using `filter` may reduce possible valid values and may impact the time required to generate a valid value.
      #
      # @example
      #   integer_generator = Pbt.integer
      #   even_integer_generator = integer_generator.filter { |x| x.even? }
      #   # or `integer_generator.filter(&:even?)`
      #
      # @param max_attempts [Integer] Maximum generation attempts before raising `FilterExhaustedError`.
      # @param refinement [Proc] Predicate proc to test each produced element. Return true to keep the element, false otherwise.
      # @return [FilterArbitrary] New arbitrary filtered using `refinement`.
      def filter(max_attempts: FilterArbitrary::DEFAULT_MAX_ATTEMPTS, &refinement)
        FilterArbitrary.new(self, max_attempts: max_attempts, &refinement)
      end
    end
  end
end
