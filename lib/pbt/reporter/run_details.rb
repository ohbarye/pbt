# frozen_string_literal: true

module Pbt
  module Reporter
    RunDetails = Struct.new(
      :failed,
      :num_runs,
      :num_shrinks,
      :seed,
      :counterexample,
      :error_message,
      :error_instance,
      :failures,
      :verbose,
      :run_configuration,
      keyword_init: true
    )
  end
end
