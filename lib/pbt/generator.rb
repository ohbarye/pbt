# frozen_string_literal: true

module Pbt
  class Generator
    def self.integer(low: nil, high: nil)
      Generator.new do
        rng = Random.new
        size = 100
        if low && high
          rng.rand(low..high)
        else
          rng.rand(-size..size)
        end
      end
    end

    def self.array(element_generator, min: 0, max: 10, empty: true)
      raise ArgumentError if min < 0
      min = 1 if min.zero? && !empty

      Generator.new do
        rng = Random.new
        amount = rng.rand(min..max)
        amount.times.map { element_generator.generate }
      end
    end

    def initialize(&block)
      @block = block
    end

    def generate
      @block.call
    end
  end
end
