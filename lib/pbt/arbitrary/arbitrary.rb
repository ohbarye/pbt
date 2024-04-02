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
    end
  end
end
