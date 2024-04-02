# frozen_string_literal: true

module Pbt
  module Arbitrary
    # @abstract
    class Arbitrary
      # @abstract
      # @param rng [Random]
      # @return [Object]
      def generate(rng)
        raise NotImplementedError
      end

      # @abstract
      # @param current [Object]
      # @return [Enumerator]
      def shrink(current)
        raise NotImplementedError
      end

      # @param mapper [Proc] a function to map the generated value. it's mainly used for #generate.
      # @param unmapper [Proc] a function to unmap the generated value. it's used for #shrink.
      def map(mapper, unmapper)
        MapArbitrary.new(self, mapper, unmapper)
      end

      # @param refinement [Proc] a function to filter the generated value and shrunken values.
      def filter(&refinement)
        FilterArbitrary.new(self, &refinement)
      end
    end
  end
end
