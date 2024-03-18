# frozen_string_literal: true

module Pbt
  class Runner
    Case = Struct.new(:val, :actor, :exception, keyword_init: true)
    private_constant :Case

    def initialize(generator, config: {}, &block)
      @generator = generator
      @config = config
      @block = block
    end

    def run
      cases = []
      @config[:case_count].times do
        val = @generator.generate
        actor = if @config[:use_ractor]
          -> { Ractor.new(val, &@block) }
        else
          -> { @block.call(val) }
        end
        cases << Case.new(val:, actor:, exception: nil)
      end

      failures = []
      cases.each do |c|
        c.actor.call
        print "." if @config[:verbose]
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
