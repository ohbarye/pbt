# frozen_string_literal: true

require_relative "example/biggest"

RSpec.describe Pbt do
  it "has a version number" do
    expect(Pbt::VERSION).not_to be nil
  end

  describe "basic usage" do
    it "describes a property" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer)) do |numbers|
          raise if PbtTest.biggest(numbers) != numbers.max
        end
      end
    end
  end
end
