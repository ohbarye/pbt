# frozen_string_literal: true

module Pbt
  class Property
    def initialize(name, config:, &block)
      @name = name
      @config = config
      @block = block
    end

    def check
      if @config[:use_ractor]
        Ractor.new(name: @name, &@block)
      else
        @block.call
      end
    end
  end
end
