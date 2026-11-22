# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a random value from a range.
    class ChooseArbitrary < Arbitrary
      # @param range [Range<Integer>]
      def initialize(range)
        @range = range
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
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
        else
          return false unless value.is_a?(Float) && value.finite?
        end

        @range.cover?(value)
      end

      # @see Arbitrary#shrink
      def shrink(current)
        # Range is ordered from min to max, so we can just shrink towards min.
        min, max = [@range.begin, @range.end].sort
        IntegerArbitrary.new(min, max).shrink(current, target: min)
      end

      private

      def integer_range?
        @range.begin.is_a?(Integer) && @range.end.is_a?(Integer)
      end

      def empty_range?
        !@range.begin.nil? && !@range.end.nil? && !@range.cover?(@range.begin)
      end
    end
  end
end
