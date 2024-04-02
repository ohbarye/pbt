# frozen_string_literal: true

module Pbt
  module Arbitrary
    class MapArbitrary < Arbitrary
      # @param arb [ArrayArbitrary]
      def initialize(arb, mapper, unmapper)
        @arb = arb
        @mapper = mapper
        @unmapper = unmapper
      end

      # @return [Array]
      def generate(rng)
        @mapper.call(@arb.generate(rng))
      end

      # @return [Enumerator]
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
