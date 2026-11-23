# frozen_string_literal: true

module Pbt
  module Arbitrary
    # A generated value and its lazy shrink tree. Each sample owns its provenance.
    class Sample
      attr_reader :value

      def initialize(value, &shrinker)
        @value = value
        @shrinker = shrinker
      end

      def shrink
        Enumerator.new { |y| @shrinker.call.each { |child| y << child } }
      end

      def map(&mapper)
        Sample.new(mapper.call(value)) do
          shrink.lazy.map { |child| child.map(&mapper) }
        end
      end

      def filter(&predicate)
        Sample.new(value) do
          shrink.lazy.select { |child| predicate.call(child.value) }.map { |child| child.filter(&predicate) }
        end
      end

      # Compatibility with user-defined generate/shrink objects.
      def self.capture(arbitrary, rng)
        if arbitrary.respond_to?(:sample)
          arbitrary.sample(rng)
        else
          from_value(arbitrary, arbitrary.generate(rng))
        end
      end

      def self.from_value(arbitrary, value)
        Sample.new(value) do
          arbitrary.shrink(value).lazy.map { |child| from_value(arbitrary, child) }
        end
      end

      def self.contextual?(arbitrary)
        arbitrary.respond_to?(:contextual?) && arbitrary.contextual?
      end

      def self.validate_bound_arbitrary!(arb)
        return arb if arb.is_a?(Arbitrary) || (arb.respond_to?(:generate) && arb.respond_to?(:shrink))

        raise ArgumentError, "bind block must return an arbitrary responding to generate and shrink, got #{arb.class}"
      end

      def self.bind(outer_sample, inner_seed, &binder)
        inner_arb = validate_bound_arbitrary!(binder.call(outer_sample.value))
        inner_sample = capture(inner_arb, Random.new(inner_seed))
        bind_samples(outer_sample, inner_sample, inner_seed, binder)
      end

      def self.bind_samples(outer_sample, inner_sample, inner_seed, binder)
        Sample.new(inner_sample.value) do
          Enumerator.new do |y|
            outer_sample.shrink.each do |shrunk_outer|
              shrunk_inner =
                begin
                  shrunk_inner_arb = validate_bound_arbitrary!(binder.call(shrunk_outer.value))
                  capture(shrunk_inner_arb, Random.new(inner_seed))
                rescue EmptyDomainError, FilterExhaustedError
                  next
                end

              y << bind_samples(shrunk_outer, shrunk_inner, inner_seed, binder)
            end

            inner_sample.shrink.each do |shrunk_inner|
              y << bind_samples(outer_sample, shrunk_inner, inner_seed, binder)
            end
          end
        end
      end
      private_class_method :bind_samples

      def self.tuple(samples)
        Sample.new(samples.map(&:value)) do
          Enumerator.new do |y|
            samples.each_with_index do |sample, index|
              sample.shrink.each do |child|
                next_samples = samples.dup
                next_samples[index] = child
                y << tuple(next_samples)
              end
            end
          end
        end
      end

      def self.array(samples, length_arbitrary, min_length)
        Sample.new(samples.map(&:value)) do
          Enumerator.new do |y|
            if samples.size > min_length
              emitted_n_minus_1 = false
              length_arbitrary.shrink(samples.size).each do |length|
                emitted_n_minus_1 = true if length == samples.size - 1
                if length.zero?
                  y << array([], length_arbitrary, min_length)
                else
                  samples.each_cons(length) { |items| y << array(items, length_arbitrary, min_length) }
                end
              end

              if samples.size >= 3
                indices = emitted_n_minus_1 ? (1...(samples.size - 1)) : (0...samples.size)
                indices.each do |i|
                  y << array([*samples[...i], *samples[i + 1..]], length_arbitrary, min_length)
                end
              end
            end

            samples.each_with_index do |sample, index|
              sample.shrink.each do |child|
                next_samples = samples.dup
                next_samples[index] = child
                y << array(next_samples, length_arbitrary, min_length)
              end
            end
          end
        end
      end
    end
  end
end
