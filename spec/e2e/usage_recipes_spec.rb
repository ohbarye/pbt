# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe "Usage recipes" do
  %w[encodings disjoint_ranges].each do |recipe|
    it "executes the #{recipe} recipe through property checks" do
      output, status = Open3.capture2e(RbConfig.ruby, "-Ilib", "examples/usage/#{recipe}.rb")
      expect(status.success?).to be(true), output
      expect(output).to include("100 cases passed")
    end
  end
end
