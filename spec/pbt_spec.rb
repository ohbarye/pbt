# frozen_string_literal: true

require_relative "example/biggest"

RSpec.describe Pbt do
  it "has a version number" do
    expect(Pbt::VERSION).not_to be nil
  end

  describe "basic usage" do
    describe "integer generator" do
      it "works" do
        Pbt.forall(Pbt::Generator.integer) do |number|
          raise TypeError unless number.is_a?(Integer)
        end
      end

      describe "arguments" do
        it "specifies range with low and high" do
          Pbt.forall(Pbt::Generator.integer(low: -3, high: 4)) do |number|
            raise TypeError unless number.is_a?(Integer) && number >= -3 && number <= 4
          end
        end
      end
    end

    describe "array generator" do
      it "works" do
        Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer)) do |numbers|
          raise TypeError unless numbers.all?(Integer)
        end
      end

      it "finds the biggest element" do
        Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer)) do |numbers|
          raise if PbtTest.biggest(numbers) != numbers.max
        end
      end

      describe "arguments" do
        it "specifies min size" do
          Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer, min: 2)) do |numbers|
            raise if numbers.size < 2
          end
        end

        it "specifies max size" do
          Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer, max: 2)) do |numbers|
            raise if numbers.size > 2
          end
        end

        it "specifies emptiness" do
          Pbt.forall(Pbt::Generator.array(Pbt::Generator.integer, empty: false)) do |numbers|
            raise if numbers.size == 0
          end
        end
      end
    end
  end
end
