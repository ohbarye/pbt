# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Abstract class for generating random values on type `T`.
    #
    # @abstract
    class Arbitrary
      # Generate a value of type `T`, based on the provided random number generator.
      #
      # @abstract
      # @param rng [Random] Random number generator.
      # @return [Object] Random value of type `T`.
      def generate(rng)
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

      # Create another arbitrary by applying `mapper` value by value.
      #
      # @example
      #   integer_generator = Pbt.integer
      #   num_str_generator = integer_arb.map(->(n){ n.to_s }, ->(s) {s.to_i})
      #
      # @param mapper [Proc] Proc to map generated values. Mainly used for generation.
      # @param unmapper [Proc] Proc to unmap generated values. Used for shrinking.
      # @return [MapArbitrary] New arbitrary with mapped elements
      def map(mapper, unmapper)
        MapArbitrary.new(self, mapper, unmapper)
      end

      # Create another arbitrary by filtering values against `refinement`.
      # All the values produced by the resulting arbitrary satisfy `!!refinement(value) == true`.
      #
      # Be aware that using `filter` may reduce possible valid values and may impact the time required to generate a valid value.
      #
      # @example
      #   integer_generator = Pbt.integer
      #   even_integer_generator = integer_arb.filter { |x| x.even? }
      #   # or `integer_arb.filter(&:even?)`
      #
      # @param refinement [Proc] Predicate proc to test each produced element. Return true to keep the element, false otherwise.
      # @return [FilterArbitrary] New arbitrary filtered using `refinement`.
      def filter(&refinement)
        FilterArbitrary.new(self, &refinement)
      end
    end
  end
end
