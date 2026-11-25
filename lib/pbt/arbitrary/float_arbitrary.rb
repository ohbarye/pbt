# frozen_string_literal: true

module Pbt
  module Arbitrary
    # Generates Float values within optional finite `Integer` / `Float` bounds, with opt-in
    # NaN / Infinity support and float-aware binary-search shrinking toward zero (or the nearest bound).
    #
    # Omitted bounds default finite generation to `-1_000_000.0..1_000_000.0` (or a scaled span for
    # large one-sided bounds), while `cover?` only enforces explicitly specified bounds.
    class FloatArbitrary < Arbitrary
      DEFAULT_MIN = -1_000_000.0
      DEFAULT_MAX = 1_000_000.0
      DEFAULT_SPAN = 1_000_000.0
      EDGE_CASE_BIAS_DENOMINATOR = 5
      MAX_SHRINK_STEPS = 16
      private_constant :DEFAULT_MIN, :DEFAULT_MAX, :DEFAULT_SPAN, :EDGE_CASE_BIAS_DENOMINATOR, :MAX_SHRINK_STEPS

      # @param min [Integer, Float, nil] Inclusive finite lower bound.
      # @param max [Integer, Float, nil] Inclusive finite upper bound.
      # @param allow_nan [Boolean] Whether `Float::NAN` may be generated. Default is `false`.
      # @param allow_infinity [Boolean] Whether `+/-Float::INFINITY` may be generated when the corresponding bound is unbounded. Default is `false`.
      def initialize(min: nil, max: nil, allow_nan: false, allow_infinity: false)
        @raw_min = validate_bound!(:min, min)
        @raw_max = validate_bound!(:max, max)
        @min = round_inward_min(@raw_min)
        @max = round_inward_max(@raw_max)
        @allow_nan = !!allow_nan
        @allow_infinity = !!allow_infinity
        @empty = empty_domain?
        @generation_bounds = @empty ? nil : compute_generation_bounds
        @special_values = compute_special_values
        @edge_cases = @empty ? [].freeze : compute_finite_edge_cases
      end

      # @see Arbitrary#generate
      def generate(rng = Random.new)
        if @empty
          raise EmptyDomainError, "no representable Float in range #{@raw_min.inspect}..#{@raw_max.inspect}"
        end

        lo, hi = @generation_bounds

        if !@special_values.empty? && rng.rand(20).zero?
          return @special_values[rng.rand(@special_values.size)]
        end

        if !@edge_cases.empty? && rng.rand(EDGE_CASE_BIAS_DENOMINATOR).zero?
          return @edge_cases[rng.rand(@edge_cases.size)]
        end

        if @min.nil? && @max.nil? && rng.rand(2).zero?
          x = rng.rand(-1_000_000..1_000_000)
          y = rng.rand(-1_000_000..1_000_000)
          return x.to_f / (y.to_f.abs + 1.0)
        end

        sample_finite(lo, hi, rng)
      end

      # @see Arbitrary#cover?
      def cover?(value)
        return false unless value.is_a?(Float)
        return false if @empty
        return @allow_nan if value.nan?

        if value.infinite?
          return false unless @allow_infinity

          return value.positive? ? @max.nil? : @min.nil?
        end

        return false if @min && value < @min
        return false if @max && value > @max

        true
      end

      # @see Arbitrary#shrink
      def shrink(current, target: nil)
        return [].each if @empty

        lo, hi = shrink_bounds(current)
        self.class.shrink_float(current, min: lo, max: hi, target: target)
      end

      # Float-aware binary-search shrink helper shared with `ChooseArbitrary`.
      # @api private
      #
      # @param current [Object]
      # @param min [Float]
      # @param max [Float]
      # @param target [Integer, Float, nil]
      # @param exclude_end [Boolean]
      # @return [Enumerator<Float>]
      def self.shrink_float(current, min:, max:, target: nil, exclude_end: false)
        return [].each unless current.is_a?(Float)
        return [].each if min > max || (exclude_end && min >= max)

        t = (target.nil? ? 0.0 : target.to_f).clamp(min, max)
        t = min if exclude_end && t >= max

        if current.nan?
          return Enumerator.new { |y| y.yield t }
        end

        if current.infinite?
          return Enumerator.new do |y|
            y.yield t
            finite_edge = current.positive? ? max : min
            y.yield finite_edge if finite_edge != t && !(exclude_end && finite_edge >= max)
          end
        end

        return [].each if current == t

        Enumerator.new do |y|
          seen = {current => true}

          emit = lambda do |val|
            clamped = val.clamp(min, max)
            return if exclude_end && clamped >= max
            return if seen.key?(clamped)

            seen[clamped] = true
            y.yield clamped
          end

          emit.call(t)

          truncated = current.truncate.to_f
          if truncated != current && truncated != t &&
              ((t < current && truncated > t && truncated < current) ||
               (t > current && truncated < t && truncated > current))
            emit.call(truncated)
          end

          step = ((current / 2.0) - (t / 2.0)).abs
          positive = current > t

          MAX_SHRINK_STEPS.times do
            break unless step.finite? && step > 0.0

            candidate = positive ? (current - step) : (current + step)
            break if candidate == current

            emit.call(candidate)
            step /= 2.0
          end
        end
      end

      private

      def validate_bound!(name, value)
        return nil if value.nil?

        valid_type = value.is_a?(Integer) || value.is_a?(Float)
        unless valid_type && value.to_f.finite?
          raise ArgumentError, "#{name} must be a finite Integer, Float, or nil, got #{value.inspect}"
        end

        value
      end

      def round_inward_min(value)
        return nil if value.nil?

        f = value.to_f
        f = f.next_float if value.is_a?(Integer) && f < value
        f
      end

      def round_inward_max(value)
        return nil if value.nil?

        f = value.to_f
        f = f.prev_float if value.is_a?(Integer) && f > value
        f
      end

      def empty_domain?
        return true if @raw_min && @raw_max && @raw_min > @raw_max
        return true if @min && !@min.finite?
        return true if @max && !@max.finite?
        return true if @min && @max && @min > @max

        false
      end

      def compute_generation_bounds
        if @min && @max
          [@min, @max].freeze
        elsif @min
          span = [DEFAULT_SPAN, @min.abs].max
          hi = [@min + span, DEFAULT_MAX].max
          [@min, hi.finite? ? hi : Float::MAX].freeze
        elsif @max
          span = [DEFAULT_SPAN, @max.abs].max
          lo = [@max - span, DEFAULT_MIN].min
          [lo.finite? ? lo : -Float::MAX, @max].freeze
        else
          [DEFAULT_MIN, DEFAULT_MAX].freeze
        end
      end

      def shrink_bounds(current)
        lo, hi = @generation_bounds
        if current.is_a?(Float) && current.finite?
          lo = [lo, current].min if @min.nil?
          hi = [hi, current].max if @max.nil?
        end
        [lo, hi]
      end

      def compute_special_values
        values = []
        values << Float::NAN if @allow_nan
        if @allow_infinity
          values << Float::INFINITY if @max.nil?
          values << -Float::INFINITY if @min.nil?
        end
        values.freeze
      end

      def compute_finite_edge_cases
        lo, hi = @generation_bounds
        return [].freeze if lo >= hi

        candidates = [0.0, 1.0, -1.0]
        candidates << -0.0 if lo < 0.0 && hi >= 0.0
        candidates << @min if @min
        candidates << @max if @max
        candidates
          .select { |v| v.between?(lo, hi) }
          .uniq { |v| v.zero? ? (1.0 / v) : v }
          .freeze
      end

      def sample_finite(lo, hi, rng)
        return lo if lo == hi

        span = hi - lo
        if span.finite?
          rng.rand(lo..hi)
        else
          # Avoid Float overflow when hi - lo exceeds Float::MAX.
          mid = (lo / 2.0) + (hi / 2.0)
          rng.rand(2).zero? ? rng.rand(lo..mid) : rng.rand(mid..hi)
        end
      end
    end
  end
end
