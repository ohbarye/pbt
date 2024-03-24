# frozen_string_literal: true

module Pbt
  module Reporter
    class RunDetailsReporter
      # @param [String] name
      # @param [Pbt::Reporter::RunExecution] run_details
      def initialize(name, run_details)
        @name = name
        @run_details = run_details
      end

      # @raise [PropertyFailure]
      def report_run_details
        if @run_details.failed
          message = []

          if @name.length > 0
            message << "Property name: #{@name}"
          end

          message << <<~EOS
            Property failed after #{@run_details.num_runs} test(s)
            { seed: #{@run_details.seed} }
            Counterexample: #{@run_details.counterexample}
            Shrunk #{@run_details.num_shrinks} time(s)
            Got #{@run_details.error_instance.class}: #{@run_details.error_message}
          EOS

          if @run_details.verbose
            message << "  \n#{@run_details.error_instance.backtrace_locations.join("\n    ")}"
            message << "\nEncountered failures were:"
            message << @run_details.failures.map { |f| "- #{f.val}" }
          end

          raise PropertyFailure, message.join("\n") if message.size > 0
        end
      end
    end
  end
end
