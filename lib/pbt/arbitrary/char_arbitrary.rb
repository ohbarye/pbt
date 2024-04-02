# frozen_string_literal: true

module Pbt
  module Arbitrary
    class CharArbitrary
      def initialize
        @arb = ChooseArbitrary.new(0..0x10FFFF)
      end

      # @return [String]
      def generate(rng)
        map(@arb.generate(rng))
      end

      # Shrinks towards characters with lower codepoints, e.g. ASCII
      # @return [Enumerator]
      def shrink(current)
        Enumerator.new do |y|
          @arb.shrink(unmap(current)).each do |v|
            y << map(v)
          end
        end
      end

      private

      def map(v)
        [v].pack("U")
      end

      def unmap(v)
        v.unpack1("U")
      end
    end
  end
end
