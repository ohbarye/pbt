# frozen_string_literal: true

require "faker"

RSpec.describe "FactoryBot and Faker recipe" do
  it "replays generated attributes and restores Faker's random source" do
    require_relative "../factory_bot"
    original = Faker::Config.random
    first = UsageRecipe.check(seed: 42)
    expect(UsageRecipe.check(seed: 42)).to eq(first)
    expect(first.size).to eq(100)
    expect(first.map { |age, _name| age }).to all(be_between(0, 120))
    expect(first.map { |_age, name| name }).to all(be_a(String))
    expect(Faker::Config.random).to equal(original)
  end
  it "restores Faker's random source when name generation fails" do
    require_relative "../factory_bot"
    original = Faker::Config.random
    allow(Faker::Name).to receive(:name).and_raise("name failed")
    expect { UsageRecipe.check(seed: 42) }.to raise_error(Pbt::PropertyFailure, /name failed/)
    expect(Faker::Config.random).to equal(original)
  end
end
