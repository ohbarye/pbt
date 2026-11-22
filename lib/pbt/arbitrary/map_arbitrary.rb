# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates a mapped value from another arbitrary.
    class MapArbitrary < Arbitrary
      # @param arb [Arbitrary] Arbitrary to generate values to be mapped.
      # @param mapper [Proc] Proc to map generated values. Mainly used for generation.
      # @param unmapper [Proc, nil] Optional proc to unmap generated values for bare `#shrink`.
      # @param bijective [Boolean] Internal flag indicating `mapper`/`unmapper` form a bijection on the codomain.
      def initialize(arb, mapper, unmapper = nil, bijective: false)
        raise ArgumentError, "mapper must be callable" unless mapper.respond_to?(:call)
        raise ArgumentError, "unmapper must be callable or nil" if !unmapper.nil? && !unmapper.respond_to?(:call)

        @arb = arb
        @mapper = mapper
        @unmapper = unmapper
        @bijective = bijective
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        @mapper.call(@arb.generate(rng))
      end

      # @private
      def contextual?
        @unmapper.nil? || Sample.contextual?(@arb)
      end

      # @see Arbitrary#sample
      def sample(rng = Random.new)
        Sample.capture(@arb, rng).map { |value| @mapper.call(value) }
      end

      # @see Arbitrary#cover?
      def cover?(value)
        return nil if @unmapper.nil?

        unmapped, mapped = begin
          u = @unmapper.call(value)
          [u, @mapper.call(u)]
        rescue
          return nil
        end

        round_trip = mapped.equal?(value) || mapped.eql?(value)
        return @bijective ? false : nil unless round_trip

        inner = Arbitrary.cover_result(@arb, unmapped)
        return true if inner == true
        return false if @bijective && inner == false

        nil
      end

      # @see Arbitrary#shrink
      def shrink(current)
        return [].each if @unmapper.nil?

        Enumerator.new do |y|
          @arb.shrink(@unmapper.call(current)).each do |v|
            y.yield @mapper.call(v)
          end
        end
      end
    end
  end
end
