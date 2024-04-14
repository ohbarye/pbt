# frozen_string_literal: true

module Pbt
  module Reporter
    # Details of a single run of a property test.
    RunDetails = Struct.new(
      :failed,
      :num_runs,
      :num_shrinks,
      :seed,
      :counterexample,
      :counterexample_path,
      :error_message,
      :error_instance,
      :failures,
      :verbose,
      :execution_summary,
      :run_configuration,
      keyword_init: true
    )
  end
end
