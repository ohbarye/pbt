# frozen_string_literal: true

module Pbt
  module Generator
    def self.integer(low = nil, high = nil)
      rng = Random.new
      size = 100
      if low && high
        -> { rng.rand(low..high) }
      else
        -> { rng.rand(-size..size) }
      end
    end
  end
end
