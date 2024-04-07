# frozen_string_literal: true

module Pbt
  module Check
    Case = Struct.new(:val, :ractor, :exception, :index, keyword_init: true)
  end
end
