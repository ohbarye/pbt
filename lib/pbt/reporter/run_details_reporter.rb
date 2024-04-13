# frozen_string_literal: true

module Pbt
  module Reporter
    # Reporter for the run details of a property test.
    class RunDetailsReporter
      # @param run_details [Pbt::Reporter::RunExecution]
      def initialize(run_details)
        @run_details = run_details
      end

      # Report the run details of a property test.
      # If the property test failed, raise a PropertyFailure.
      #
      # @raise [PropertyFailure]
      def report_run_details
        if @run_details.failed
          message = []

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
