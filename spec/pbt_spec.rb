# frozen_string_literal: true

require_relative "example/biggest"

RSpec.describe Pbt do
  it "has a version number" do
    expect(Pbt::VERSION).not_to be nil
  end

  describe "basic usage" do
    it "has integer generator" do
      Pbt.assert "generates only integer" do
        Pbt.property(Pbt.integer) do |number|
          raise TypeError unless number.is_a?(Integer)
        end
      end

      Pbt.assert "is able to specify range with low and high" do
        Pbt.property(Pbt.integer(low: -3, high: 4)) do |number|
          raise TypeError unless number >= -3 && number <= 4
        end
      end
    end

    it "has array generator" do
      Pbt.assert "generates an array of a given generator" do
        Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
          raise TypeError unless numbers.all?(Integer)
        end
      end

      Pbt.assert "finds the biggest element" do
        Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
          raise if PbtTest.biggest(numbers) != numbers.max
        end
      end

      Pbt.assert "is able to specify min size" do
        Pbt.property(Pbt.array(Pbt.integer, min: 2)) do |numbers|
          raise if numbers.size < 2
        end
      end

      Pbt.assert "is able to specify max size" do
        Pbt.property(Pbt.array(Pbt.integer, max: 2)) do |numbers|
          raise if numbers.size > 2
        end
      end

      Pbt.assert "is able to specify emptiness" do
        Pbt.property(Pbt.array(Pbt.integer, empty: false)) do |numbers|
          raise if numbers.size == 0
        end
      end
    end
  end

  describe "configuration" do
    it "can be configured for each property" do
      Pbt.assert "finds the biggest element", params: {num_runs: 5, use_ractor: false} do
        Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
          raise if PbtTest.biggest(numbers) != numbers.max
        end
      end
    end

    it "can be configured for all" do
      Pbt.configure do |config|
        config.verbose = false
        config.num_runs = 100
        config.use_ractor = true
      end

      Pbt.assert "finds the biggest element" do
        Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
          raise if PbtTest.biggest(numbers) != numbers.max
        end
      end
    end
  end
end
