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
          message << format_error_message
          message << error_backtrace
          message << if @run_details.verbose
            verbose_details
          else
            hint
          end

          raise PropertyFailure, message.join("\n") if message.size > 0
        end
      end

      private

      # @return [String]
      def format_error_message
        <<~MSG.chomp
          Property failed after #{@run_details.num_runs} test(s)
          { seed: #{@run_details.seed} }
          Counterexample: #{@run_details.counterexample}
          Shrunk #{@run_details.num_shrinks} time(s)
          Got #{@run_details.error_instance.class}: #{@run_details.error_message}
        MSG
      end

      def error_backtrace
        i = @run_details.verbose ? -1 : 10
        "    #{@run_details.error_instance.backtrace_locations[..i].join("\n    ")}"
      end

      # @return [String]
      def verbose_details
        [
          "\nEncountered failures were:",
          @run_details.failures.map { |f| "- #{f.val}" },
          format_execution_summary
        ].join("\n")
      end

      # @return [String]
      def format_execution_summary
        summary_lines = []
        remaining_trees_and_depth = []

        @run_details.execution_summary.reverse_each do |tree|
          remaining_trees_and_depth << {depth: 1, tree:}
        end

        until remaining_trees_and_depth.empty?
          current_tree_and_depth = remaining_trees_and_depth.pop

          # format current tree according to its depth and result
          current_tree = current_tree_and_depth[:tree]
          current_depth = current_tree_and_depth[:depth]
          result_icon = case current_tree.result
          in :success
            "\x1b[32m\u221A\x1b[0m" # green "√"
          in :failure
            "\x1b[31m\u00D7\x1b[0m" # red "×"
          end
          left_padding = ". " * current_depth
          summary_lines << "#{left_padding}#{result_icon} #{current_tree.value}"

          # push its children to the queue
          current_tree.children.reverse_each do |tree|
            remaining_trees_and_depth << {depth: current_depth + 1, tree:}
          end
        end

        "\nExecution summary:\n#{summary_lines.join("\n")}\n"
      end

      # @return [String]
      def hint
        [
          "\nHint: Set `verbose: true` in order to check the list of all failing values encountered during the run.",
          "Hint: Set `seed: #{@run_details.seed}` in order to reproduce the failed test case with the same values."
        ].join("\n")
      end
    end
  end
end
