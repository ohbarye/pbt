# frozen_string_literal: true

RSpec.describe Pbt::Check::RunnerIterator do
  describe "#handle_result hooks" do
    it "gives shrink_case precedence over c.sample and property#shrink" do
      sample = Pbt::Arbitrary::Sample.new(10) { [Pbt::Arbitrary::Sample.new(999)].each }
      property = Object.new
      def property.shrink(_val)
        [888].each
      end

      def property.shrink_case(c)
        [c.val - 1, c.val - 2].each
      end

      iterator = described_class.new([sample].each, property, false)
      failing_case = Pbt::Check::Case.new(val: 10, sample: sample, index: 0, exception: RuntimeError.new("boom"))

      expect(iterator.handle_result(failing_case)).to be(true)
      expect(iterator.to_a).to eq([9, 8])
    end

    it "ignores shrink candidates that fail with a different error when same_failure? returns false" do
      expected_error = Class.new(StandardError)
      unrelated_error = Class.new(StandardError)

      property = Object.new
      property.define_singleton_method(:generate) { |_rng| 10 }
      property.define_singleton_method(:shrink) do |val|
        case val
        when 10 then [5, 2, 1].each
        when 2 then [1].each
        else [].each
        end
      end
      property.define_singleton_method(:same_failure?) do |initial, candidate|
        initial.instance_of?(candidate.class)
      end
      property.define_singleton_method(:run) do |val|
        raise unrelated_error, "different bug" if val == 5
        raise expected_error, "target bug" if val >= 2
      end

      result = Pbt.check(num_runs: 1, seed: 1, worker: :none) { property }

      expect(result.failed).to be(true)
      expect(result.counterexample).to eq(2)
      expect(result.error_instance).to be_a(expected_error)
      expect(result.num_shrinks).to eq(1)
      expect(result.counterexample_path).to eq("0:1")
    end

    it "keeps the initial failure intact when all shrink candidates raise unrelated errors" do
      expected_error = Class.new(StandardError)
      unrelated_error = Class.new(StandardError)

      property = Object.new
      property.define_singleton_method(:generate) { |_rng| 10 }
      property.define_singleton_method(:shrink) { |val| (val == 10) ? [5, 1].each : [].each }
      property.define_singleton_method(:same_failure?) { |initial, candidate| initial.instance_of?(candidate.class) }
      property.define_singleton_method(:run) do |val|
        raise expected_error, "original" if val == 10
        raise unrelated_error, "unrelated"
      end

      result = Pbt.check(num_runs: 1, seed: 1, worker: :none) { property }

      expect(result.failed).to be(true)
      expect(result.counterexample).to eq(10)
      expect(result.error_instance).to be_a(expected_error)
      expect(result.num_shrinks).to eq(0)
    end

    it "also respects same_failure? under :ractor worker" do
      property = Object.new
      property.define_singleton_method(:generate) { |_rng| 10 }
      property.define_singleton_method(:shrink) do |val|
        case val
        when 10 then [5, 2, 1].each
        when 2 then [1].each
        else [].each
        end
      end
      property.define_singleton_method(:same_failure?) do |initial, candidate|
        initial.instance_of?(candidate.class)
      end
      property.define_singleton_method(:run_in_ractor) do |val|
        Ractor.new(val) do |v|
          raise ArgumentError, "different bug" if v == 5
          raise "target bug" if v >= 2
        end
      end

      result = Pbt.check(num_runs: 1, seed: 1, worker: :ractor) { property }

      expect(result.failed).to be(true)
      expect(result.counterexample).to eq(2)
      expect(result.error_instance).to be_a(RuntimeError)
      expect(result.num_shrinks).to eq(1)
      expect(result.counterexample_path).to eq("0:1")
    end
  end
end
