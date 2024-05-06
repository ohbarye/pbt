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
                  counterexample: [2, 11]
                  Shrunk 16 time(s)
                  Got RuntimeError: strings should be sorted as numbers ["11", "2"]
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
                  counterexample: [2, 11]
                  Shrunk 16 time(s)
                  Got RuntimeError: strings should be sorted as numbers ["11", "2"]
              MSG

              # verbose part
              expect(e.message).to include <<~MSG
                Encountered failures were:
                - [152477, 666997, -531468, -92182, 623948, 425913, 656138, 856463, -64529]
                - [76239, 666997, -531468, -92182, 623948, 425913, 656138, 856463, -64529]
                - [76239, 666997, -531468, -92182, 623948]
                - [76239, 666997, -531468]
                - [76239, 666997]
                - [9530, 666997]
                - [75, 666997]
                - [75, 333499]
                - [38, 333499]
                - [5, 333499]
                - [5, 166750]
                - [3, 166750]
                - [2, 166750]
                - [2, 10422]
                - [2, 1303]
                - [2, 163]
                - [2, 11]

                Execution summary:
                . \x1b[31m\u00D7\x1b[0m [152477, 666997, -531468, -92182, 623948, 425913, 656138, 856463, -64529]
                . . \x1b[32m\u221A\x1b[0m [152477, 666997, -531468, -92182, 623948]
                . . \x1b[32m\u221A\x1b[0m [666997, -531468, -92182, 623948, 425913]
                . . \x1b[32m\u221A\x1b[0m [-531468, -92182, 623948, 425913, 656138]
                . . \x1b[32m\u221A\x1b[0m [-92182, 623948, 425913, 656138, 856463]
                . . \x1b[32m\u221A\x1b[0m [623948, 425913, 656138, 856463, -64529]
                . . \x1b[32m\u221A\x1b[0m [152477, 666997, -531468]
                . . \x1b[32m\u221A\x1b[0m [666997, -531468, -92182]
                . . \x1b[32m\u221A\x1b[0m [-531468, -92182, 623948]
                . . \x1b[32m\u221A\x1b[0m [-92182, 623948, 425913]
                . . \x1b[32m\u221A\x1b[0m [623948, 425913, 656138]
                . . \x1b[32m\u221A\x1b[0m [425913, 656138, 856463]
                . . \x1b[32m\u221A\x1b[0m [656138, 856463, -64529]
                . . \x1b[32m\u221A\x1b[0m [152477, 666997]
                . . \x1b[32m\u221A\x1b[0m [666997, -531468]
                . . \x1b[32m\u221A\x1b[0m [-531468, -92182]
                . . \x1b[32m\u221A\x1b[0m [-92182, 623948]
                . . \x1b[32m\u221A\x1b[0m [623948, 425913]
                . . \x1b[32m\u221A\x1b[0m [425913, 656138]
                . . \x1b[32m\u221A\x1b[0m [656138, 856463]
                . . \x1b[32m\u221A\x1b[0m [856463, -64529]
                . . \x1b[32m\u221A\x1b[0m [152477]
                . . \x1b[32m\u221A\x1b[0m [666997]
                . . \x1b[32m\u221A\x1b[0m [-531468]
                . . \x1b[32m\u221A\x1b[0m [-92182]
                . . \x1b[32m\u221A\x1b[0m [623948]
                . . \x1b[32m\u221A\x1b[0m [425913]
                . . \x1b[32m\u221A\x1b[0m [656138]
                . . \x1b[32m\u221A\x1b[0m [856463]
                . . \x1b[32m\u221A\x1b[0m [-64529]
                . . \x1b[32m\u221A\x1b[0m []
                . . \x1b[31m\u00D7\x1b[0m [76239, 666997, -531468, -92182, 623948, 425913, 656138, 856463, -64529]
                . . . \x1b[31m\u00D7\x1b[0m [76239, 666997, -531468, -92182, 623948]
                . . . . \x1b[31m\u00D7\x1b[0m [76239, 666997, -531468]
                . . . . . \x1b[31m\u00D7\x1b[0m [76239, 666997]
                . . . . . . \x1b[32m\u221A\x1b[0m [76239]
                . . . . . . \x1b[32m\u221A\x1b[0m [666997]
                . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . \x1b[32m\u221A\x1b[0m [38120, 666997]
                . . . . . . \x1b[32m\u221A\x1b[0m [19060, 666997]
                . . . . . . \x1b[31m\u00D7\x1b[0m [9530, 666997]
                . . . . . . . \x1b[32m\u221A\x1b[0m [9530]
                . . . . . . . \x1b[32m\u221A\x1b[0m [666997]
                . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . \x1b[32m\u221A\x1b[0m [4765, 666997]
                . . . . . . . \x1b[32m\u221A\x1b[0m [2383, 666997]
                . . . . . . . \x1b[32m\u221A\x1b[0m [1192, 666997]
                . . . . . . . \x1b[32m\u221A\x1b[0m [596, 666997]
                . . . . . . . \x1b[32m\u221A\x1b[0m [298, 666997]
                . . . . . . . \x1b[32m\u221A\x1b[0m [149, 666997]
                . . . . . . . \x1b[31m\u00D7\x1b[0m [75, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [75]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . \x1b[32m\u221A\x1b[0m [38, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [19, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [10, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [5, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [3, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [1, 666997]
                . . . . . . . . \x1b[32m\u221A\x1b[0m [0, 666997]
                . . . . . . . . \x1b[31m\u00D7\x1b[0m [75, 333499]
                . . . . . . . . . \x1b[32m\u221A\x1b[0m [75]
                . . . . . . . . . \x1b[32m\u221A\x1b[0m [333499]
                . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . \x1b[31m\u00D7\x1b[0m [38, 333499]
                . . . . . . . . . . \x1b[32m\u221A\x1b[0m [38]
                . . . . . . . . . . \x1b[32m\u221A\x1b[0m [333499]
                . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . \x1b[32m\u221A\x1b[0m [19, 333499]
                . . . . . . . . . . \x1b[32m\u221A\x1b[0m [10, 333499]
                . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [5, 333499]
                . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [5]
                . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [333499]
                . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [3, 333499]
                . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 333499]
                . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [1, 333499]
                . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [0, 333499]
                . . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [5, 166750]
                . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [5]
                . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [166750]
                . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [3, 166750]
                . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [3]
                . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [166750]
                . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [2, 166750]
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2]
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [166750]
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [1, 166750]
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [0, 166750]
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 83375]
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 41688]
                . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 20844]
                . . . . . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [2, 10422]
                . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2]
                . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [10422]
                . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [1, 10422]
                . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [0, 10422]
                . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 5211]
                . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 2606]
                . . . . . . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [2, 1303]
                . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2]
                . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [1303]
                . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [1, 1303]
                . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [0, 1303]
                . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 652]
                . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 326]
                . . . . . . . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [2, 163]
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2]
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [163]
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [1, 163]
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [0, 163]
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 82]
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 41]
                . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 21]
                . . . . . . . . . . . . . . . . . \x1b[31m\u00D7\x1b[0m [2, 11]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [11]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m []
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [1, 11]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [0, 11]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 6]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 3]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 2]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 1]
                . . . . . . . . . . . . . . . . . . \x1b[32m\u221A\x1b[0m [2, 0]
              MSG
            end
          end
        end
      end
    end
  end
end
