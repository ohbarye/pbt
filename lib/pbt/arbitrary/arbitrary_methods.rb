# frozen_string_literal: true

module Pbt
  module Arbitrary
    module ArbitraryMethods
      def integer(low: nil, high: nil)
        Generator.new do |rng|
          size = 10000
          if low && high
            rng.rand(low..high)
          else
            rng.rand(-size..size)
          end
        end
      end

      def array(element_generator, min: 0, max: 10, empty: true)
        raise ArgumentError if min < 0
        min = 1 if min.zero? && !empty

        Generator.new do |rng|
          amount = rng.rand(min..max)
          amount.times.map { element_generator.generate(rng) }
        end
      end
    end
  end
end
