# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates random integers between `min` and `max`.
    class IntegerArbitrary < Arbitrary
      DEFAULT_TARGET = 0
      private_constant :DEFAULT_TARGET

      # @param min [Integer] Minimum value to generate.
      # @param max [Integer] Maximum value to generate.
      def initialize(min, max)
        raise ArgumentError, "min and max cannot be nil" if min.nil? || max.nil?

        @min = min
        @max = max
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        rng.rand(@min..@max)
      rescue ArgumentError => e
        raise EmptyDomainError, e.message if @min > @max

        raise
      end

      # @see Arbitrary#cover?
      def cover?(value)
        return false unless value.is_a?(Integer)
        return false if !@min.nil? && value < @min
        return false if !@max.nil? && value > @max

        true
      end

      # @see Arbitrary#shrink
      def shrink(current, target: nil)
        target ||= DEFAULT_TARGET.clamp(@min, @max)
        target = target.clamp(@min, @max)

        gap = current - target
        return Enumerator.new { |_| } if gap == 0

        is_positive_gap = gap > 0

        Enumerator.new do |y|
          last_yielded = target
          y.yield target

          step = gap.abs
          while step > 1
            step = step.is_a?(Integer) ? ((step + 1) / 2) : (step / 2.0)
            break if step < 1

            candidate = (is_positive_gap ? (current - step) : (current + step)).clamp(@min, @max)
            if candidate != current && candidate != last_yielded
              y.yield candidate
              last_yielded = candidate
            end
          end
        end
      end
    end
  end
end
