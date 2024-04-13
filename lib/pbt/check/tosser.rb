# frozen_string_literal: true

module Pbt
  module Check
    # Module to be included in classes that need to generate values to test.
    module Tosser
      # Generate values.
      #
      # @param arb [Arbitrary] Arbitrary to generate a value.
      # @param seed [Integer] Random number generator's seed.
      # @return [Enumerator]
      def toss(arb, seed)
        Enumerator.new do |enum|
          rng = Random.new(seed)
          loop do
            enum.yield toss_next(arb, rng)
          end
        end
      end

      private

      # Generate next value.
      #
      # @param arb [Arbitrary] Arbitrary to generate a value.
      # @param rng [Random] Random number generator.
      def toss_next(arb, rng)
        arb.generate(rng)
      end
    end
  end
end
