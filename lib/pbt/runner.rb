# frozen_string_literal: true

module Pbt
  class Runner
    CASE_COUNT = 100
    Case = Struct.new(:val, :ractor, :exception, keyword_init: true)
    private_constant :CASE_COUNT, :Case

    def initialize(generator, &block)
      @generator = generator
      @block = block
    end

    def run
      cases = []
      CASE_COUNT.times do
        val = @generator.call
        ractor = Ractor.new(val, &@block)
        cases << Case.new(val:, ractor:, exception: nil)
      end

      failures = []
      cases.each do |c|
        c.ractor.take
      rescue => e
        c.exception = e.cause
        failures << c
      end

      message = []
      failures.group_by { _1.exception.class }.each do |exception_class, failures|
        message << <<~EOS
          #{exception_class}:
            Failed on:
              #{failures.map(&:val).join("\n    ")}
        EOS
      end

      raise CaseFailure, message.join("\n") if failures.size > 0
    end
  end
end
