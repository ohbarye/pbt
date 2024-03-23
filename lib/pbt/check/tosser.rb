# frozen_string_literal: true

module Pbt
  module Check
    module Tosser
      def toss_next(generator, rng)
        generator.generate(rng)
      end

      def toss(generator, seed)
        Enumerator.new do |enum|
          rng = Random.new(seed)
          loop do
            enum.yield toss_next(generator, rng)
          end
        end
      end
    end
  end
end
