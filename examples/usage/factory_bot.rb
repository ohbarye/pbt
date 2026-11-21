# frozen_string_literal: true

require "pbt"
require "factory_bot"
require "faker"

module UsageRecipe
  User = Struct.new(:age, :name)

  FactoryBot.define do
    factory :pbt_recipe_user, class: "UsageRecipe::User" do
      initialize_with { new(**attributes) }
    end
  end

  # Build a fresh unsaved object per case, passing every random attribute explicitly.
  # Faker's seed is itself a generated input, so PBT can replay and shrink it.
  def self.check(seed:)
    observed = []
    Pbt.assert(seed: seed, num_runs: 100, worker: :none) do
      Pbt.property(age: Pbt.integer(min: 0, max: 120), faker_seed: Pbt.integer(min: 0, max: 1_000_000)) do |age:, faker_seed:|
        previous_random = Faker::Config.random
        begin
          Faker::Config.random = Random.new(faker_seed)
          name = Faker::Name.name
          user = FactoryBot.build(:pbt_recipe_user, age: age, name: name)
          raise "attributes changed" unless user.age == age && user.name == name
          observed << [user.age, user.name]
        ensure
          Faker::Config.random = previous_random
        end
      end
    end
    observed
  end
end

if $PROGRAM_NAME == __FILE__
  UsageRecipe.check(seed: 42)
  puts "100 cases passed for FactoryBot and Faker"
end
