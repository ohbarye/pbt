# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates one of the given constant values.
    class ConstantFromArbitrary < Arbitrary
      # @param choices [Array<Object>] Non-empty list of constant choices.
      def initialize(choices)
        raise EmptyDomainError, "constant_from requires at least one choice" if choices.empty?

        @choices = choices.dup
        @idx_arb = IntegerArbitrary.new(0, @choices.size - 1)
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        @choices[@idx_arb.generate(rng)]
      end

      # @see Arbitrary#cover?
      def cover?(value)
        @choices.any? { |choice| choice.equal?(value) || choice.eql?(value) }
      end

      # @see Arbitrary#shrink
      def shrink(current)
        index = @choices.index { |choice| choice.equal?(current) || choice.eql?(current) }
        return Enumerator.new {} if index.nil?

        # Shrinks to values earlier in the list of `choices`.
        Enumerator.new do |y|
          @idx_arb.shrink(index).each do |idx|
            y << @choices[idx]
          end
        end
      end
    end
  end
end
