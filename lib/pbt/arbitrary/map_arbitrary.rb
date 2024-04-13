# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a mapped value from another arbitrary.
    class MapArbitrary < Arbitrary
      # @param arb [Arbitrary] Arbitrary to generate values to be mapped.
      # @param mapper [Proc] Proc to map generated values. Mainly used for generation.
      # @param unmapper [Proc] Proc to unmap generated values. Used for shrinking.
      def initialize(arb, mapper, unmapper)
        @arb = arb
        @mapper = mapper
        @unmapper = unmapper
      end

      # @see Arbitrary#generate
      def generate(rng)
        @mapper.call(@arb.generate(rng))
      end

      # @see Arbitrary#shrink
      def shrink(current)
        Enumerator.new do |y|
          @arb.shrink(@unmapper.call(current)).each do |v|
            y.yield @mapper.call(v)
          end
        end
      end
    end
  end
end
