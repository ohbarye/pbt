# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a random value from a range.
    class ChooseArbitrary < Arbitrary
      # @param range [Range<Integer>, Range<Float>]
      def initialize(range)
        @range = range
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        if float_range? && @range.exclude_end?
          return sample_exclusive_float(rng)
        end

        rng.rand(@range)
      rescue ArgumentError => e
        raise EmptyDomainError, e.message if empty_range?

        raise
      end

      # @see Arbitrary#cover?
      def cover?(value)
        return false if @range.begin.nil? || @range.end.nil?

        if integer_range?
          return false unless value.is_a?(Integer)
        elsif float_range?
          return false unless value.is_a?(Float) && value.finite?
        end

        @range.cover?(value)
      end

      # @see Arbitrary#shrink
      def shrink(current)
        return [].each if @range.begin.nil? || @range.end.nil? || empty_range?

        min = @range.begin
        max = @range.end
        if integer_range?
          effective_max = @range.exclude_end? ? (max - 1) : max
          return [].each if min > effective_max

          IntegerArbitrary.new(min, effective_max).shrink(current, target: min)
        elsif float_range?
          FloatArbitrary.shrink_float(
            current,
            min: min.to_f,
            max: max.to_f,
            target: min.to_f,
            exclude_end: @range.exclude_end?
          )
        else
          [].each
        end
      end

      private

      def integer_range?
        @range.begin.is_a?(Integer) && @range.end.is_a?(Integer)
      end

      def float_range?
        @range.begin.is_a?(Float) || @range.end.is_a?(Float)
      end

      def empty_range?
        !@range.begin.nil? && !@range.end.nil? && !@range.cover?(@range.begin)
      end

      def sample_exclusive_float(rng)
        raise EmptyDomainError, "cannot generate from empty range #{@range.inspect}" if empty_range?

        lo = @range.begin.to_f
        hi = @range.end.to_f.prev_float
        if !lo.finite? || !hi.finite? || lo > hi
          raise EmptyDomainError, "cannot generate from range #{@range.inspect}"
        end

        return lo if lo == hi

        span = hi - lo
        if span.finite?
          rng.rand(lo..hi)
        else
          mid = (lo / 2.0) + (hi / 2.0)
          rng.rand(2).zero? ? rng.rand(lo..mid) : rng.rand(mid..hi)
        end
      end
    end
  end
end
