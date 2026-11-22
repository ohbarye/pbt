# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Selects a generator using nonnegative integer weights.
    class FrequencyArbitrary < Arbitrary
      def initialize(choices)
        unless choices.all? { |pair|
          pair.is_a?(Array) && pair.size == 2 && pair[0].is_a?(Integer) && pair[0] >= 0 &&
              pair[1].respond_to?(:generate) && pair[1].respond_to?(:shrink)
        }
          raise ArgumentError, "frequency expects [nonnegative Integer weight, arbitrary] pairs"
        end
        @choices = choices.select { |weight, _| weight.positive? }.map(&:dup)
        @total = @choices.sum(&:first)
        raise ArgumentError, "frequency requires at least one positive weight" if @total.zero?
      end

      def generate(rng = Random.new)
        select(rng).generate(rng)
      end

      # Preserve the selected branch for shrinking, even after subsequent generation.
      def sample(rng = Random.new)
        Sample.capture(select(rng), rng)
      end

      def contextual?
        true
      end

      # @see Arbitrary#cover?
      def cover?(value)
        unknown = false
        @choices.each do |_weight, arb|
          covered = arb.respond_to?(:cover?) ? arb.cover?(value) : nil
          return true if covered == true

          unknown = true if covered.nil?
        end
        unknown ? nil : false
      end

      # A bare value cannot identify its branch. Use sample or Pbt.property to shrink.
      def shrink(current)
        [].each
      end

      private

      def select(rng)
        ticket = rng.rand(@total)
        @choices.each do |weight, arbitrary|
          return arbitrary if ticket < weight

          ticket -= weight
        end
      end
    end
  end
end
