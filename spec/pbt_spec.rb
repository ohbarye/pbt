# frozen_string_literal: true

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
  end
end
