# frozen_string_literal: true

RSpec.describe Pbt do
  around do |ex|
    Thread.report_on_exception = false
    ex.run
    Thread.report_on_exception = true
  end

  describe "arguments" do
    it "passes a value that the given single arbitrary generates" do
      Pbt.assert do
        Pbt.property(self, Pbt.integer) do |n|
          puts "called!!!!!!!!!!!!!"
          puts n
          raise unless n.is_a?(Integer)
        end
      end
    end
  end
end
