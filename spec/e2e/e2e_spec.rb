# frozen_string_literal: true

require_relative "example/pbt_test_target"

RSpec.describe Pbt do
  describe "basic usage" do
    it "describes a property" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
          raise if PbtTestTarget.biggest(numbers) != numbers.max
        end
      end
    end

    it "raises Pbt::PropertyFailure when the property fails" do
      expect {
        Pbt.assert params: {num_runs: 1} do
          Pbt.property(Pbt.integer(min: 0, max: 0)) do |numbers|
            PbtTestTarget.reciprocal(numbers)
          end
        end
      }.to raise_error(Pbt::PropertyFailure) do |e|
        [
          "Property failed 1 time(s) in 1 tests\n",
          "{ seed: ",
          "Counterexample: 0\n",
          "Shrunk 0 time(s)\n",
          "Got ZeroDivisionError: divided by 0\n"
        ].each { |m| expect(e.message).to include m }
      end
    end
  end
end
