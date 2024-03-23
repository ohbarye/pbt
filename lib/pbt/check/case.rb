# frozen_string_literal: true

module Pbt
  module Check
    Case = Struct.new(:val, :actor, :exception, keyword_init: true)
  end
end
