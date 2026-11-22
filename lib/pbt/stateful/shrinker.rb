# frozen_string_literal: true

require "pbt/arbitrary/sample"
require "pbt/stateful/errors"
require "pbt/stateful/types"

module Pbt
  module Stateful
    # Per-failure shrink session sharing deduplication state and attempt budget across shrink passes.
    class ShrinkSession
      attr_reader :attempts, :max_attempts

      def initialize(max_attempts:)
        @max_attempts = max_attempts
        @attempts = 0
        @seen = {}
      end

      def exhausted?
        @attempts >= @max_attempts
      end

      def seen?(run)
        @seen.key?(run)
      end

      def mark_seen(run)
        @seen[run] = true
      end

      def consume_attempt!
        @attempts += 1
      end
    end

    # Internal provenance wrapper carrying a pure `Run` alongside contextual `Sample` shrink trees.
    class RunSample < Pbt::Arbitrary::Sample
      attr_reader :initial_state_sample, :step_samples, :session

      def initialize(run, initial_state_sample:, step_samples:, session:)
        @initial_state_sample = initial_state_sample
        @step_samples = step_samples
        @session = session
        super(run) { [].each }
      end

      def run
        value
      end
    end

    # Best-first stateful shrinker with offline 6-step model validation, deduplication, and attempt budget.
    class Shrinker
      def initialize(spec)
        @spec = spec
      end

      # Build a lazy Enumerator of valid shrunk `RunSample` candidates for `run_sample`.
      #
      # @param run_sample [RunSample]
      # @param failure [Exception, nil]
      # @return [Enumerator<RunSample>]
      def shrink(run_sample, failure:)
        run = run_sample.run
        session = run_sample.session
        session.mark_seen(run)

        Enumerator.new do |y|
          next if session.exhausted?

          # Stage 1: Immediate post-failure truncation.
          if failure.is_a?(StepFailure)
            truncated_steps = post_failure_truncation(run.steps, failure)
            if truncated_steps
              candidate = Run.new(initial_state: run.initial_state, steps: truncated_steps.freeze)
              status = emit_candidate(
                y,
                candidate,
                session: session,
                initial_state_sample: run_sample.initial_state_sample,
                step_samples: run_sample.step_samples,
                validate: false
              )
              next if status == :exhausted
            end
          end

          # Stage 2: Chunk deletions (ddmin-style, back to front).
          next if shrink_by_chunk_deletions(y, run_sample, session) == :exhausted

          # Stage 3: Single-step deletions (back to front).
          next if shrink_by_single_deletions(y, run_sample, session) == :exhausted

          # Stage 4: Initial state shrinking (when initial_state is an Arbitrary).
          next if shrink_initial_state(y, run_sample, session) == :exhausted

          # Stage 5: Step argument shrinking (step 0..n-1).
          shrink_step_arguments(y, run_sample, session)
        end
      end

      # Validate a candidate run purely against the model without touching the SUT.
      #
      # @param run [Run]
      # @return [Boolean]
      def valid_run?(run)
        state = Resolver.deep_freeze(run.initial_state)
        available_ids = Set.new

        run.steps.each do |step|
          ref_ids = Resolver.collect_ref_ids(step.args)
          return false unless ref_ids.all? { |id| available_ids.include?(id) }

          command = @spec.command_by_name(step.command)
          return false unless command.guard?(state)

          arb =
            begin
              command.arguments_for(state)
            rescue Pbt::Arbitrary::EmptyDomainError
              return false
            end

          return false if Pbt::Arbitrary::Arbitrary.cover_result(arb, step.args) == false
          return false unless command.precondition?(state, step.args)

          state = command.next_state(state, step.args, Ref.new(step_id: step.id))
          available_ids << step.id
        end

        true
      end

      private

      def post_failure_truncation(steps, failure)
        if failure.step_index.is_a?(Integer) && failure.step_index < steps.length - 1
          steps[0..failure.step_index]
        elsif failure.step_index.nil? && (failure.stage == :invariant || failure.stage == :sut) && !steps.empty?
          []
        end
      end

      def shrink_by_chunk_deletions(y, run_sample, session)
        run = run_sample.run
        steps = run.steps
        n = steps.length
        chunk_size = n / 2

        while chunk_size >= 2
          chunk_starts(n, chunk_size).each do |start|
            kept = steps[0...start] + steps[(start + chunk_size)..]
            candidate = Run.new(initial_state: run.initial_state, steps: kept.freeze)
            status = emit_candidate(
              y,
              candidate,
              session: session,
              initial_state_sample: run_sample.initial_state_sample,
              step_samples: run_sample.step_samples
            )
            return :exhausted if status == :exhausted
          end
          chunk_size /= 2
        end

        :ok
      end

      def chunk_starts(length, chunk_size)
        starts = []
        pos = length - chunk_size
        while pos >= 0
          starts << pos
          pos -= chunk_size
        end
        starts << 0 unless starts.last == 0
        starts
      end

      def shrink_by_single_deletions(y, run_sample, session)
        run = run_sample.run
        steps = run.steps
        (steps.length - 1).downto(0) do |idx|
          kept = steps[0...idx] + steps[(idx + 1)..]
          candidate = Run.new(initial_state: run.initial_state, steps: kept.freeze)
          status = emit_candidate(
            y,
            candidate,
            session: session,
            initial_state_sample: run_sample.initial_state_sample,
            step_samples: run_sample.step_samples
          )
          return :exhausted if status == :exhausted
        end

        :ok
      end

      def shrink_initial_state(y, run_sample, session)
        initial_sample = run_sample.initial_state_sample
        return :ok unless initial_sample

        run = run_sample.run
        initial_sample.shrink.each do |child_sample|
          frozen_state = Resolver.deep_freeze(child_sample.value)
          candidate = Run.new(initial_state: frozen_state, steps: run.steps)
          status = emit_candidate(
            y,
            candidate,
            session: session,
            initial_state_sample: child_sample,
            step_samples: run_sample.step_samples
          )
          return :exhausted if status == :exhausted
        end

        :ok
      end

      def shrink_step_arguments(y, run_sample, session)
        run = run_sample.run
        steps = run.steps
        step_samples = run_sample.step_samples
        state = run.initial_state

        steps.each_with_index do |step, idx|
          command = @spec.command_by_name(step.command)
          step_sample = step_samples[step.id]

          if step_sample
            step_sample.shrink.each do |child_sample|
              new_step = Step.new(id: step.id, command: step.command, args: child_sample.value)
              new_steps = steps.dup
              new_steps[idx] = new_step
              candidate = Run.new(initial_state: run.initial_state, steps: new_steps.freeze)
              status = emit_candidate(
                y,
                candidate,
                session: session,
                initial_state_sample: run_sample.initial_state_sample,
                step_samples: step_samples.merge(step.id => child_sample)
              )
              return :exhausted if status == :exhausted
            end
          else
            arb =
              begin
                command.arguments_for(state)
              rescue Pbt::Arbitrary::EmptyDomainError
                nil
              end
            arb&.shrink(step.args)&.each do |shrunk_arg|
              new_step = Step.new(id: step.id, command: step.command, args: shrunk_arg)
              new_steps = steps.dup
              new_steps[idx] = new_step
              candidate = Run.new(initial_state: run.initial_state, steps: new_steps.freeze)
              status = emit_candidate(
                y,
                candidate,
                session: session,
                initial_state_sample: run_sample.initial_state_sample,
                step_samples: step_samples
              )
              return :exhausted if status == :exhausted
            end
          end

          state = command.next_state(state, step.args, Ref.new(step_id: step.id))
        end

        :ok
      end

      def emit_candidate(y, candidate, session:, initial_state_sample:, step_samples:, validate: true)
        return :exhausted if session.exhausted?
        return :duplicate if session.seen?(candidate)

        session.mark_seen(candidate)
        session.consume_attempt!

        return :invalid if validate && !valid_run?(candidate)

        y << RunSample.new(
          candidate,
          initial_state_sample: initial_state_sample,
          step_samples: step_samples,
          session: session
        )
        :emitted
      end
    end
  end
end
