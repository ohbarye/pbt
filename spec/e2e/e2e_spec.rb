# frozen_string_literal: true

require_relative "example/pbt_test_target"

RSpec.describe Pbt do
  around do |ex|
    Thread.report_on_exception = false
    ex.run
    Thread.report_on_exception = true
  end

  describe "basic usage" do
    it "describes a property" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
          raise if PbtTestTarget.biggest(numbers) != numbers.max
        end
      end
    end

    describe "property failure" do
      it "describes a property" do
        Pbt.assert do
          Pbt.property(Pbt.integer, Pbt.integer) do |n1, n2 = 1| # TODO: remove default value
            raise if PbtTestTarget.biggest([n1, n2]) != [n1, n2].max
          end
        end
      end
    end

    describe "property failure" do
      context "no shrinking" do
        it "raises Pbt::PropertyFailure and describes the failure" do
          expect {
            Pbt.assert params: {num_runs: 1} do
              Pbt.property(Pbt.integer(min: 0, max: 0)) do |number|
                result = PbtTestTarget.multiplicative_inverse(number)
                raise "Result should be the multiplicative inverse of the number" if result * number != 1
              end
            end
          }.to raise_error(Pbt::PropertyFailure) do |e|
            [
              "Property failed after 1 test(s)\n",
              "{ seed: ",
              "Counterexample: 0\n",
              "Shrunk 0 time(s)\n",
              "Got ZeroDivisionError: divided by 0\n"
            ].each { |m| expect(e.message).to include m }
          end
        end
      end

      context "with shrinking" do
        it "raises Pbt::PropertyFailure and describes the failure" do
          expect {
            Pbt.assert do
              Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
                str_numbers = numbers.map(&:to_s)
                result = PbtTestTarget.sort_as_integer(str_numbers)
                raise "strings should be sorted as numbers #{result}" if result != numbers.sort.map(&:to_s)
              end
            end
          }.to raise_error(Pbt::PropertyFailure) do |e|
            [
              /Property failed after [\d]+ test\(s\)/,
              "{ seed: ",
              "Counterexample: ",
              /Shrunk [\d]+ time\(s\)\n/,
              "ot RuntimeError: strings should be sorted as numbers "
            ].each { |m| expect(e.message).to match m }
          end
        end
      end
    end
  end
end
