# frozen_string_literal: true

module Pbt
  module Check
    class Property
      # @param arb [Pbt::Arbitrary::Generator]
      # @param predicate [Proc]
      def initialize(arb, &predicate)
        @arb = arb
        @predicate = predicate
      end

      # @param rng [Random]
      # @return [Object]
      def generate(rng)
        @arb.generate(rng)
      end

      # @param val [Object]
      # @return [Object]
      def shrink(val)
        @arb.shrink(val)
      end

      # @param val [Object]
      # @param use_ractor [Boolean]
      # @return [Ractor, RactorPretender]
      def run(val, use_ractor)
        if use_ractor
          Ractor.new(val, &@predicate)
        else
          RactorPretender.new(val: val, predicate: @predicate)
        end
      end

      RactorPretender = Struct.new(:val, :predicate, keyword_init: true) do
        def take
          predicate.call(val)
        rescue => cause
          raise StandardError.new("Wrapped error. See cause"), cause: cause
        end
      end
    end
  end
end
