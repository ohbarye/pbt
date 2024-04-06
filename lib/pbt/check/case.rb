# frozen_string_literal: true

module Pbt
  module Check
    Case = Struct.new(:val, :ractor, :exception, keyword_init: true)
  end
end
