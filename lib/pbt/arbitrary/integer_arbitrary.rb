# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates random integers between `min` and `max`.
    class IntegerArbitrary < Arbitrary
      DEFAULT_TARGET = 0
      EDGE_CASE_DOMAIN_THRESHOLD = 20
      EDGE_CASE_BIAS_DENOMINATOR = 5
      private_constant :DEFAULT_TARGET, :EDGE_CASE_DOMAIN_THRESHOLD, :EDGE_CASE_BIAS_DENOMINATOR

      # @param min [Integer] Minimum value to generate.
      # @param max [Integer] Maximum value to generate.
      def initialize(min, max)
        raise ArgumentError, "min and max cannot be nil" if min.nil? || max.nil?

        @min = min
        @max = max
        @edge_cases = build_edge_cases
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        if @edge_cases && rng.rand(EDGE_CASE_BIAS_DENOMINATOR).zero?
          return @edge_cases[rng.rand(@edge_cases.size)]
        end

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

      private

      def build_edge_cases
        return nil unless @min.is_a?(Integer) && @max.is_a?(Integer)
        return nil if @min > @max
        return nil if (@max - @min + 1) <= EDGE_CASE_DOMAIN_THRESHOLD

        [0, 1, -1, @min, @max].uniq.select { |v| v.between?(@min, @max) }.freeze
      end
    end
  end
end
