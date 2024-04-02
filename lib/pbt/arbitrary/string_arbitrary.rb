# frozen_string_literal: true

module Pbt
  module Arbitrary
    class StringArbitrary
      # @param arb [ArrayArbitrary]
      def initialize(arb)
        @arb = arb
      end

      # @return [Array]
      def generate(rng)
        map(@arb.generate(rng))
      end

      # @return [Enumerator]
      def shrink(current)
        Enumerator.new do |y|
          @arb.shrink(unmap(current)).each do |v|
            y.yield map(v)
          end
        end
      end

      private

      def map(v)
        v.join
      end

      def unmap(v)
        v.chars
      end
    end
  end
end
