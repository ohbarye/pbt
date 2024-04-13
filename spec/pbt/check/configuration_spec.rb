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
                thread_report_on_exception: false
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
                thread_report_on_exception: false
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
                thread_report_on_exception: false
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
                thread_report_on_exception: false
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
                thread_report_on_exception: false
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
                thread_report_on_exception: false
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
                thread_report_on_exception: false
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
                thread_report_on_exception: false
              }
            )
          end
        end
      end
    end
  end
end
