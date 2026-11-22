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

      it "passes an empty Hash from a single positional arbitrary as a value, not empty kwargs" do
        [:none, :ractor].each do |worker|
          Pbt.assert(worker: worker, num_runs: 3) do
            Pbt.property(Pbt.constant({}), &->(val) { raise "expected Hash, got #{val.inspect}" unless val == {} })
          end
        end
      end

      it "splats multiple positional arbitraries for strict lambdas under both :none and :ractor" do
        [:none, :ractor].each do |worker|
          Pbt.assert(worker: worker, num_runs: 5) do
            Pbt.property(Pbt.integer, Pbt.integer, &->(x, y) { raise unless x.is_a?(Integer) && y.is_a?(Integer) })
          end
        end
      end

      it "passes keyword arguments to the predicate under default :none worker" do
        Pbt.assert(worker: :none, num_runs: 10) do
          Pbt.property(x: Pbt.integer, y: Pbt.integer) do |x:, y:|
            raise unless x.is_a?(Integer)
            raise unless y.is_a?(Integer)
          end
        end
      end

      it "does not fail when a predicate merely returns false without raising" do
        details = Pbt.check(worker: :none, num_runs: 5) do
          Pbt.property(Pbt.integer) { |_n| false }
        end

        expect(details.failed).to be(false)
        expect(details.num_runs).to eq(5)
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
          seed = 6478147390881634219670054323585906496
          expect {
            Pbt.assert(seed:, num_runs: 1) do
              Pbt.property(Pbt.integer(min: 0, max: 0)) do |number|
                result = PbtTestTarget.multiplicative_inverse(number)
                raise "Result should be the multiplicative inverse of the number" if result * number != 1
              end
            end
          }.to raise_error(Pbt::PropertyFailure) do |e|
            expect(e.message).to include <<~MSG.chomp
              Property failed after 1 test(s)
                seed: 6478147390881634219670054323585906496
                counterexample: 0
                Shrunk 0 time(s)
                Got ZeroDivisionError: divided by 0
            MSG
          end
        end
      end

      context "with shrinking" do
        context "verbose = false" do
          it "raises Pbt::PropertyFailure and describes the failure" do
            seed = 152305683944880796308915131809827264455
            expect {
              Pbt.assert(seed:, verbose: false) do
                Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
                  str_numbers = numbers.map(&:to_s)
                  result = PbtTestTarget.sort_as_integer(str_numbers)
                  raise "strings should be sorted as numbers #{result}" if result != numbers.sort.map(&:to_s)
                end
              end
            }.to raise_error(Pbt::PropertyFailure) do |e|
              expect(e.message).to include <<~MSG.chomp
                Property failed after 1 test(s)
                  seed: 152305683944880796308915131809827264455
                  counterexample: [-1, -2]
                  Shrunk 37 time(s)
                  Got RuntimeError: strings should be sorted as numbers ["-1", "-2"]
              MSG
            end
          end
        end

        context "verbose = true" do
          it "raises Pbt::PropertyFailure and describes the failure with verbosity" do
            seed = 152305683944880796308915131809827264455
            expect {
              Pbt.assert(seed:, verbose: true) do
                Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
                  str_numbers = numbers.map(&:to_s)
                  result = PbtTestTarget.sort_as_integer(str_numbers)
                  raise "strings should be sorted as numbers #{result}" if result != numbers.sort.map(&:to_s)
                end
              end
            }.to raise_error(Pbt::PropertyFailure) do |e|
              # common part
              expect(e.message).to include <<~MSG
                Property failed after 1 test(s)
                  seed: 152305683944880796308915131809827264455
                  counterexample: [-1, -2]
                  Shrunk 37 time(s)
                  Got RuntimeError: strings should be sorted as numbers ["-1", "-2"]
              MSG

              # verbose part
              expect(e.message).to include("Encountered failures were:\n- [152477, 666997, -531468, -92182, 623948, 425913, 656138, 856463, -64529]")
              expect(e.message).to include("- [-1, -2]\n\nExecution summary:\n. \x1b[31m\u00D7\x1b[0m [152477, 666997, -531468, -92182, 623948, 425913, 656138, 856463, -64529]")
              expect(e.message).to include("\x1b[31m\u00D7\x1b[0m [-1, -2]")
              expect(e.message).to include("\x1b[32m\u221A\x1b[0m [-1, 0]")
            end
          end
        end
      end
    end
  end
end
