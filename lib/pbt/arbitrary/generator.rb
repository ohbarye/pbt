# frozen_string_literal: true

module Pbt
  module Arbitrary
    class Generator
      def initialize(&block)
        @block = block
      end

      def generate(rng)
        @block.call(rng)
      end
    end
  end
end
