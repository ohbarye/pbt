# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates values from another arbitrary, but only if they pass a predicate.
    class FilterArbitrary < Arbitrary
      DEFAULT_MAX_ATTEMPTS = 1_000

      # @param arb [Arbitrary] Arbitrary to generate values to be filtered.
      # @param max_attempts [Integer] Maximum generation attempts before raising `FilterExhaustedError`.
      # @param refinement [Proc] Predicate proc to test each produced element. Return true to keep the element, false otherwise.
      def initialize(arb, max_attempts: DEFAULT_MAX_ATTEMPTS, &refinement)
        raise ArgumentError, "filter requires a block" unless refinement
        unless max_attempts.is_a?(Integer) && max_attempts.positive?
          raise ArgumentError, "max_attempts must be a positive Integer"
        end

        @arb = arb
        @max_attempts = max_attempts
        @refinement = refinement
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        @max_attempts.times do
          val = @arb.generate(rng)
          return val if @refinement.call(val)
        end

        raise FilterExhaustedError, "FilterArbitrary failed to generate a matching value after #{@max_attempts} attempts"
      end

      def contextual?
        Sample.contextual?(@arb)
      end

      def sample(rng = Random.new)
        @max_attempts.times do
          sample = Sample.capture(@arb, rng)
          return sample.filter(&@refinement) if @refinement.call(sample.value)
        end

        raise FilterExhaustedError, "FilterArbitrary failed to generate a matching value after #{@max_attempts} attempts"
      end

      # @see Arbitrary#cover?
      def cover?(value)
        base = Arbitrary.cover_result(@arb, value)
        return false if base == false

        passed = begin
          !!@refinement.call(value)
        rescue
          return nil
        end

        passed ? base : false
      end

      # @see Arbitrary#shrink
      def shrink(current)
        Enumerator.new do |y|
          @arb.shrink(current).each do |v|
            if @refinement.call(v)
              y.yield v
            else
              next
            end
          end
        end
      end
    end
  end
end
