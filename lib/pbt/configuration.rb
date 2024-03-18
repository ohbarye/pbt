# frozen_string_literal: true

module Pbt
  ConfigurationStruct = Struct.new(
    :verbose,
    :use_ractor,
    :case_count,
    keyword_init: true
  ) do
    def initialize(verbose: false, use_ractor: true, case_count: 100)
      super
    end
  end

  def self.configure(&block)
    puts "warning: Pbt is already configured. You're overriding the configuration." if const_defined?(:Configuration)

    config = ConfigurationStruct.new
    yield(config) if block
    Pbt.const_set(:Configuration, config.freeze)
  end
end
