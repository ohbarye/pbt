# frozen_string_literal: true

RSpec.describe Pbt::Check::Configuration do
  describe "configuration" do
    describe "for each runners" do
      it "can be configured for each runner" do
        runs = 0
        Pbt.assert params: {num_runs: 5, use_ractor: false} do
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
          config.use_ractor = false
        end

        ex.run

        # rollback the configuration
        Pbt.configure do |config|
          config.num_runs = 100
          config.use_ractor = true
        end
      end

      it "can be configured for all" do
        runs = 0
        Pbt.assert "finds the biggest element" do
          Pbt.property(Pbt.integer) do |_|
            runs += 1
          end
        end
        expect(runs).to eq 2
      end
    end
  end
end
