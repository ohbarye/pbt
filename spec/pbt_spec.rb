# frozen_string_literal: true

require_relative "example/biggest"

RSpec.describe Pbt do
  it "has a version number" do
    expect(Pbt::VERSION).not_to be nil
  end

  describe "basic usage" do
    it "works" do
      Pbt.forall(Pbt::Generator.integer) do |number|
        raise TypeError unless number.is_a?(Integer)
      end
    end

    it "finds the biggest element" do
      Pbt.forall(Pbt::Generator.integer) do |number|
        numbers = (0..number).to_a
        raise if PbtTest.biggest(numbers) != numbers.max
      end
    end
  end
end
