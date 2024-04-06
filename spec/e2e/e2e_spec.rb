# frozen_string_literal: true

require_relative "example/pbt_test_target"

RSpec.describe Pbt do
  describe ".property" do
    describe "arguments" do
      it "passes a value that the given single arbitrary generates" do
        Pbt.assert do
          Pbt.property(Pbt.integer) do |n|
            raise unless n.is_a?(Integer)
          end
        end
      end

      it "passes values that the given multiple arbitrary generates" do
        Pbt.assert do
          Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
            raise unless x.is_a?(Integer)
            raise unless y.is_a?(Integer)
          end
        end
      end

      it "passes values that the given hashed arbitrary generates" do
        Pbt.assert do
          # As of Ruby 3.3.0 Ractor doesn't allow to pass keyword arguments to a block.
          # This should be `Pbt.property(x: Pbt.integer, y: Pbt.integer) do |x: y:|`.
          Pbt.property(x: Pbt.integer, y: Pbt.integer) do |h|
            raise unless h.keys == [:x, :y]
            raise unless h[:x].is_a?(Integer)
            raise unless h[:y].is_a?(Integer)
          end
        end
      end

      it "doesn't allow to use both positional and keyword arguments" do
        expect {
          Pbt.assert do
            Pbt.property(Pbt.integer, x: Pbt.integer, y: Pbt.integer) { |_| }
          end
        }.to raise_error(ArgumentError)
      end
    end
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
          Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
            raise if PbtTestTarget.biggest([x, y]) != [x, y].max
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
