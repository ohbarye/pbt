# frozen_string_literal: true

RSpec.describe Pbt do
  describe "arguments" do
    it "passes a value that the given single arbitrary generates" do
      RSpec::Matchers::BuiltIn.constants.each { |c| RSpec::Matchers::BuiltIn.const_get(c) }

      r = Ractor.new do
        loop do
          v, msg = Ractor.receive
          v.instance_eval msg
        end
      end

      r.send([self, "expect(1).to eq 1"]) # move: true doesn't work by TypeError: can't create instance of singleton class

      begin
        r.take
      rescue => e
        raise e.cause
      end

      # Pbt.assert do
      #   Pbt.property(self, Pbt.integer) do |n|
      #     puts "called!!!!!!!!!!!!!"
      #     puts n
      #     raise unless n.is_a?(Integer)
      #   end
      # end
    end
  end
end
