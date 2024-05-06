# frozen_string_literal: true

RSpec.describe Pbt::Check::Configuration do
  describe "configuration" do
    describe "scope" do
      describe "for each runners" do
        it "can be configured for each runner" do
          runs = 0
          Pbt.assert num_runs: 5, worker: :none do
            Pbt.property(Pbt.integer) do |_|
              runs += 1 # To count the number of runs, this test disables Ractor
            end
          end
          expect(runs).to eq 5
        end
      end

      describe "for all runners" do
        around do |ex|
          Pbt.configure do |config|
            config.num_runs = 2
            config.worker = :none
          end

          ex.run

          # rollback the configuration
          Pbt.configure do |config|
            config.num_runs = 100
            config.worker = :ractor
          end
        end

        it "can be configured for all" do
          run_details = Pbt.check do
            Pbt.property(Pbt.integer) {}
          end
          expect(run_details.num_runs).to eq 2
        end
      end
    end

    describe "worker" do
      describe ":ractor" do
        context "when all cases pass" do
          it "reports success" do
            run_details = Pbt.check num_runs: 5, worker: :ractor do
              Pbt.property(Pbt.integer) {}
            end

            expect(run_details.to_h).to include(
              failed: false,
              num_runs: 5,
              num_shrinks: 0,
              seed: anything,
              counterexample: nil,
              counterexample_path: nil,
              error_message: nil,
              error_instance: nil,
              failures: [],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :ractor,
                num_runs: 5,
                seed: anything,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end

        context "when any cases fail" do
          it "reports failure" do
            seed = 0

            # This seed generates [5, 1, 4] and the 4 fails.
            # Then it shrinks from 4 towards with [3, 2, 1] and finds 2 as the smallest counterexample.
            run_details = Pbt.check num_runs: 10, worker: :ractor, seed: do
              Pbt.property(Pbt.one_of(1, 2, 3, 4, 5)) do |n|
                raise "dummy error" if n % 2 == 0
              end
            end

            expect(run_details.to_h).to include(
              failed: true,
              num_runs: 3,
              num_shrinks: 1,
              seed:,
              counterexample: 2,
              counterexample_path: "2:1",
              error_message: "dummy error",
              error_instance: be_a(RuntimeError),
              failures: [anything, anything],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :ractor,
                num_runs: 10,
                seed:,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end
      end

      describe ":thread" do
        context "when all cases pass" do
          it "reports success" do
            run_details = Pbt.check num_runs: 5, worker: :thread do
              Pbt.property(Pbt.integer) {}
            end

            expect(run_details.to_h).to include(
              failed: false,
              num_runs: 5,
              num_shrinks: 0,
              seed: anything,
              counterexample: nil,
              counterexample_path: nil,
              error_message: nil,
              error_instance: nil,
              failures: [],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :thread,
                num_runs: 5,
                seed: anything,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end

        context "when any cases fail" do
          it "reports failure" do
            seed = 0

            # This seed generates [5, 1, 4] and the 4 fails.
            # Then it shrinks from 4 towards with [3, 2, 1] and finds 2 as the smallest counterexample.
            run_details = Pbt.check num_runs: 10, worker: :thread, seed: do
              Pbt.property(Pbt.one_of(1, 2, 3, 4, 5)) do |n|
                raise "dummy error" if n % 2 == 0
              end
            end

            expect(run_details.to_h).to include(
              failed: true,
              num_runs: 3,
              num_shrinks: 1,
              seed:,
              counterexample: 2,
              counterexample_path: "2:1",
              error_message: "dummy error",
              error_instance: be_a(RuntimeError),
              failures: [anything, anything],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :thread,
                num_runs: 10,
                seed:,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end
      end

      describe ":process" do
        context "when all cases pass" do
          it "reports success" do
            run_details = Pbt.check num_runs: 5, worker: :process do
              Pbt.property(Pbt.integer) {}
            end

            expect(run_details.to_h).to include(
              failed: false,
              num_runs: 5,
              num_shrinks: 0,
              seed: anything,
              counterexample: nil,
              counterexample_path: nil,
              error_message: nil,
              error_instance: nil,
              failures: [],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :process,
                num_runs: 5,
                seed: anything,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end

        context "when any cases fail" do
          it "reports failure" do
            seed = 0

            # This seed generates [5, 1, 4] and the 4 fails.
            # Then it shrinks from 4 towards with [3, 2, 1] and finds 2 as the smallest counterexample.
            run_details = Pbt.check num_runs: 10, worker: :process, seed: do
              Pbt.property(Pbt.one_of(1, 2, 3, 4, 5)) do |n|
                raise "dummy error" if n % 2 == 0
              end
            end

            expect(run_details.to_h).to include(
              failed: true,
              num_runs: 3,
              num_shrinks: 1,
              seed:,
              counterexample: 2,
              counterexample_path: "2:1",
              error_message: "dummy error",
              error_instance: be_a(RuntimeError),
              failures: [anything, anything],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :process,
                num_runs: 10,
                seed:,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end
      end

      describe ":none" do
        context "when all cases pass" do
          it "reports success" do
            run_details = Pbt.check num_runs: 5, worker: :none do
              Pbt.property(Pbt.integer) {}
            end

            expect(run_details.to_h).to include(
              failed: false,
              num_runs: 5,
              num_shrinks: 0,
              seed: anything,
              counterexample: nil,
              counterexample_path: nil,
              error_message: nil,
              error_instance: nil,
              failures: [],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :none,
                num_runs: 5,
                seed: anything,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end

        context "when any cases fail" do
          it "reports failure" do
            seed = 0

            # This seed generates [5, 1, 4] and the 4 fails.
            # Then it shrinks from 4 towards with [3, 2, 1] and finds 2 as the smallest counterexample.
            run_details = Pbt.check num_runs: 10, worker: :none, seed: do
              Pbt.property(Pbt.one_of(1, 2, 3, 4, 5)) do |n|
                raise "dummy error" if n % 2 == 0
              end
            end

            expect(run_details.to_h).to include(
              failed: true,
              num_runs: 3,
              num_shrinks: 1,
              seed:,
              counterexample: 2,
              counterexample_path: "2:1",
              error_message: "dummy error",
              error_instance: be_a(RuntimeError),
              failures: [anything, anything],
              verbose: false,
              run_configuration: {
                verbose: false,
                worker: :none,
                num_runs: 10,
                seed:,
                thread_report_on_exception: false,
                experimental_ractor_rspec_integration: false
              }
            )
          end
        end
      end

      describe "arguments to be passed" do
        describe "ractor" do
          it "allows to use RSpec expectation and matchers" do
            Pbt.assert(worker: :ractor) do
              Pbt.property(Pbt.integer) do |x|
                raise unless x.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :ractor) do
              Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
                raise unless x.is_a?(Integer)
                raise unless y.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :ractor) do
              Pbt.property(Pbt.array(Pbt.integer, empty: false)) do |arr|
                raise unless arr.is_a?(Array)
                raise unless arr[0].is_a?(Integer)
              end
            end

            Pbt.assert(worker: :ractor) do
              Pbt.property(x: Pbt.integer, y: Pbt.char) do |h|
                raise unless h.is_a?(Hash)
                raise unless h[:x].is_a?(Integer)
                raise unless h[:y].is_a?(String)
              end
            end

            # In Ractor worker mode, it's not possible to use keyword arguments.
            # Because the code calls `Ractor.new(val, ->(x:,y:){})`, to pass the `val` as keyword arguments,
            # it should be `Ractor.new(**val, &->(x:,y:){})`. But the `val` is interpreted as Ractor's arguments.
            #
            # Pbt.assert(worker: :ractor) do
            #   Pbt.property(x: Pbt.integer, y: Pbt.char) do |x:, y:|
            #     raise unless x.is_a?(Integer)
            #     raise unless y.is_a?(String)
            #   end
            # end
          end
        end

        describe "process" do
          it "allows to use RSpec expectation and matchers" do
            Pbt.assert(worker: :process) do
              Pbt.property(Pbt.integer) do |x|
                raise unless x.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :process) do
              Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
                raise unless x.is_a?(Integer)
                raise unless y.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :process) do
              Pbt.property(Pbt.array(Pbt.integer, empty: false)) do |arr|
                raise unless arr.is_a?(Array)
                raise unless arr[0].is_a?(Integer)
              end
            end

            Pbt.assert(worker: :process) do
              Pbt.property(x: Pbt.integer, y: Pbt.char) do |h|
                raise unless h.is_a?(Hash)
                raise unless h[:x].is_a?(Integer)
                raise unless h[:y].is_a?(String)
              end
            end

            Pbt.assert(worker: :process) do
              Pbt.property(x: Pbt.integer, y: Pbt.char) do |x:, y:|
                raise unless x.is_a?(Integer)
                raise unless y.is_a?(String)
              end
            end
          end
        end

        describe "thread" do
          it "allows to use RSpec expectation and matchers" do
            Pbt.assert(worker: :thread) do
              Pbt.property(Pbt.integer) do |x|
                raise unless x.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :thread) do
              Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
                raise unless x.is_a?(Integer)
                raise unless y.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :thread) do
              Pbt.property(Pbt.array(Pbt.integer, empty: false)) do |arr|
                raise unless arr.is_a?(Array)
                raise unless arr[0].is_a?(Integer)
              end
            end

            Pbt.assert(worker: :thread) do
              Pbt.property(x: Pbt.integer, y: Pbt.char) do |h|
                raise unless h.is_a?(Hash)
                raise unless h[:x].is_a?(Integer)
                raise unless h[:y].is_a?(String)
              end
            end

            Pbt.assert(worker: :thread) do
              Pbt.property(x: Pbt.integer, y: Pbt.char) do |x:, y:|
                raise unless x.is_a?(Integer)
                raise unless y.is_a?(String)
              end
            end
          end
        end

        describe "none" do
          it "allows to use RSpec expectation and matchers" do
            Pbt.assert(worker: :none) do
              Pbt.property(Pbt.integer) do |x|
                raise unless x.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :none) do
              Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
                raise unless x.is_a?(Integer)
                raise unless y.is_a?(Integer)
              end
            end

            Pbt.assert(worker: :none) do
              Pbt.property(Pbt.array(Pbt.integer, empty: false)) do |arr|
                raise unless arr.is_a?(Array)
                raise unless arr[0].is_a?(Integer)
              end
            end

            Pbt.assert(worker: :none) do
              Pbt.property(x: Pbt.integer, y: Pbt.char) do |h|
                raise unless h.is_a?(Hash)
                raise unless h[:x].is_a?(Integer)
                raise unless h[:y].is_a?(String)
              end
            end

            Pbt.assert(worker: :none) do
              Pbt.property(x: Pbt.integer, y: Pbt.char) do |x:, y:|
                raise unless x.is_a?(Integer)
                raise unless y.is_a?(String)
              end
            end
          end
        end
      end
    end

    describe "experimental_ractor_rspec_integration" do
      it "allows to use RSpec expectation and matchers" do
        Pbt.assert num_runs: 5, worker: :ractor, experimental_ractor_rspec_integration: true do
          Pbt.property(Pbt.integer) do |x|
            expect(x).to be_a(Integer)
          end
        end

        Pbt.assert num_runs: 5, worker: :ractor, experimental_ractor_rspec_integration: true do
          Pbt.property(Pbt.integer, Pbt.integer) do |x, y|
            expect(x + y).to be_a(Integer)
          end
        end

        Pbt.assert num_runs: 5, worker: :ractor, experimental_ractor_rspec_integration: true do
          Pbt.property(Pbt.array(Pbt.integer, empty: false)) do |nums|
            expect(nums).to be_a(Array)
            expect(nums[0]).to be_a(Integer)
          end
        end

        Pbt.assert num_runs: 5, worker: :ractor, experimental_ractor_rspec_integration: true do
          Pbt.property(x: Pbt.integer, y: Pbt.integer) do |x:, y:|
            expect(x + y).to be_a(Integer)
          end
        end
      end

      it "raises Pbt::PropertyFailure that wraps RSpec's exception when expectation failed" do
        expect {
          seed = 135479457171118952930684770951487304295
          Pbt.assert num_runs: 5, worker: :ractor, seed:, experimental_ractor_rspec_integration: true do
            Pbt.property(Pbt.integer) do |i|
              expect(i).to be_a(String)
            end
          end
        }.to raise_error(Pbt::PropertyFailure) do |e|
          expect(e.message).to include <<~MSG.chomp
            Property failed after 1 test(s)
              seed: 135479457171118952930684770951487304295
              counterexample: 0
              Shrunk 21 time(s)
              Got RSpec::Expectations::ExpectationNotMetError: expected 0 to be a kind of String
          MSG
        end
      end
    end
  end
end
