# frozen_string_literal: true

RSpec.describe "Pbt.assume" do
  [:none, :ractor].each do |worker|
    context "with worker: #{worker.inspect}" do
      it "discards cases failing the precondition and still completes num_runs non-skipped runs" do
        result = Pbt.check(seed: 42, num_runs: 20, worker: worker) do
          Pbt.property(Pbt.integer(min: -10, max: 10)) do |n|
            Pbt.assume(n != 0)
            raise "unexpected zero" if n == 0
          end
        end

        expect(result.failed).to be(false)
        expect(result.num_runs).to eq(20)
        expect(result.num_skips).to be >= 0
      end

      it "skips precondition-violating candidates during shrinking" do
        result = Pbt.check(seed: 1, num_runs: 50, worker: worker) do
          Pbt.property(Pbt.integer(min: 0, max: 100)) do |n|
            Pbt.assume(n.odd?)
            raise "odd too big" if n >= 5
          end
        end

        expect(result.failed).to be(true)
        expect(result.counterexample).to be_odd
        expect(result.counterexample).to eq(5)
        expect(result.num_shrinks).to be > 0
      end

      it "fails with TooManySkipsError when skips exceed max_skips" do
        result = Pbt.check(seed: 1, num_runs: 10, max_skips: 5, worker: worker) do
          Pbt.property(Pbt.integer(min: 0, max: 10)) do |_n|
            Pbt.assume(false)
          end
        end

        expect(result.failed).to be(true)
        expect(result.num_runs).to eq(0)
        expect(result.num_skips).to eq(6)
        expect(result.error_instance).to be_a(Pbt::TooManySkipsError)
        expect(result.error_instance).to be_a(Pbt::PropertyFailure)
      end

      it "raises TooManySkipsError from Pbt.assert with a helpful message" do
        expect {
          Pbt.assert(seed: 1, num_runs: 5, max_skips: 3, worker: worker) do
            Pbt.property(Pbt.integer) do |_n|
              Pbt.assume(false)
            end
          end
        }.to raise_error(Pbt::TooManySkipsError, /Too many skipped runs.*seed: 1.*Pbt\.assume/m)
      end
    end
  end

  it "counts actual non-skipped predicate executions accurately" do
    executed = []
    result = Pbt.check(seed: 42, num_runs: 15, worker: :none) do
      Pbt.property(Pbt.integer(min: 0, max: 3)) do |n|
        Pbt.assume(n.even?)
        executed << n
      end
    end

    expect(result.failed).to be(false)
    expect(executed.size).to eq(15)
    expect(executed).to all(be_even)
    expect(result.num_runs).to eq(15)
    expect(result.num_skips).to be > 0
  end

  it "validates max_skips configuration" do
    [-1, 1.5, "10"].each do |invalid|
      expect {
        Pbt.check(num_runs: 1, max_skips: invalid, worker: :none) do
          Pbt.property(Pbt.constant(1)) {}
        end
      }.to raise_error(Pbt::InvalidConfiguration, /max_skips/)
    end
  end

  it "allows max_skips: 0 when no skips happen and fails on the first skip" do
    passing = Pbt.check(num_runs: 3, max_skips: 0, worker: :none) do
      Pbt.property(Pbt.constant(1)) { |n| Pbt.assume(n == 1) }
    end
    expect(passing.failed).to be(false)

    failing = Pbt.check(num_runs: 3, max_skips: 0, worker: :none) do
      Pbt.property(Pbt.constant(1)) { |n| Pbt.assume(n == 2) }
    end
    expect(failing.failed).to be(true)
    expect(failing.error_instance).to be_a(Pbt::TooManySkipsError)
  end
end
