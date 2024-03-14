# frozen_string_literal: true

require_relative "example/biggest"

RSpec.describe Pbt do
  it "has a version number" do
    expect(Pbt::VERSION).not_to be nil
  end

  describe "basic usage" do
    after do
      Pbt.wait_for_all_properties
    end

    it "has integer generator" do
      Pbt.property "generates only integer" do
        Pbt.forall(Pbt::Generator.integer) do |number|
          raise TypeError unless number.is_a?(Integer)
        end
      end

      Pbt.property "is able to specify range with low and high" do
        Pbt.forall(Pbt::Generator.integer(low: -3, high: 4)) do |number|
          raise TypeError unless number >= -3 && number <= 4
        end
      end
    end

    it "has array generator" do
      Pbt.property "generates an array of a given generator" do
        Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer)) do |numbers|
          raise TypeError unless numbers.all?(Integer)
        end
      end

      Pbt.property "finds the biggest element" do
        Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer)) do |numbers|
          raise if PbtTest.biggest(numbers) != numbers.max
        end
      end

      Pbt.property "is able to specify min size" do
        Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer, min: 2)) do |numbers|
          raise if numbers.size < 2
        end
      end

      Pbt.property "is able to specify max size" do
        Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer, max: 2)) do |numbers|
          raise if numbers.size > 2
        end
      end

      Pbt.property "is able to specify emptiness" do
        Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer, empty: false)) do |numbers|
          raise if numbers.size == 0
        end
      end
    end
  end
end
