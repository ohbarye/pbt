# frozen_string_literal: true

require "pbt/stateful/errors"
require "pbt/stateful/types"
require "pbt/stateful/command"
require "pbt/stateful/spec"
require "pbt/stateful/shrinker"

module Pbt
  module Stateful
    # Property-compatible stateful test driver backing `Pbt.stateful { |m| ... }`.
    class Property
      PER_STEP_MAX_ATTEMPTS = 32
      private_constant :PER_STEP_MAX_ATTEMPTS

      attr_reader :spec, :max_steps, :min_steps, :max_shrink_attempts

      # @param spec [Spec]
      # @param max_steps [Integer]
      # @param min_steps [Integer]
      # @param max_shrink_attempts [Integer]
      def initialize(spec:, max_steps: 20, min_steps: 1, max_shrink_attempts: 1_000)
        validate_options!(max_steps: max_steps, min_steps: min_steps, max_shrink_attempts: max_shrink_attempts)

        @spec = spec
        @max_steps = max_steps
        @min_steps = min_steps
        @max_shrink_attempts = max_shrink_attempts
        @shrinker = Shrinker.new(spec)
      end

      def stateful?
        true
      end

      # Generate a pure immutable `Pbt::Stateful::Run` (compatible with `Pbt.statistics`).
      #
      # @param rng [Random]
      # @return [Run]
      def generate(rng = Random.new)
        generate_for_check(rng).value
      end

      # Generate a `RunSample` carrying contextual shrink provenance for `Pbt.check` / `Pbt.assert`.
      #
      # @param rng [Random]
      # @return [RunSample]
      def generate_for_check(rng = Random.new)
        initial_state, initial_state_sample = @spec.sample_initial_state(rng)
        initial_eligible = eligible_commands(initial_state)

        if initial_eligible.empty? && !@spec.arbitrary_initial_state? && @max_steps.positive?
          raise InvalidSpec,
            "no command guard is truthy at initial_state #{Resolver.format_value(initial_state)}"
        end

        target_length = (@min_steps == @max_steps) ? @min_steps : rng.rand(@min_steps..@max_steps)
        state = initial_state
        steps = []
        step_samples = {}
        next_id = 0

        target_length.times do |step_index|
          eligible = (step_index == 0) ? initial_eligible : eligible_commands(state)
          if eligible.empty?
            break if steps.length >= @min_steps

            raise GenerationError,
              "no eligible commands at step #{step_index} " \
              "(state: #{Resolver.format_value(state)}, min_steps: #{@min_steps})"
          end

          selected = select_step(eligible, state, step_index, next_id, rng)
          if selected.nil?
            break if steps.length >= @min_steps

            raise GenerationError,
              "all eligible commands produced empty argument domains at step #{step_index} " \
              "(eligible: #{eligible.map(&:name).inspect})"
          end

          step, sample, next_state = selected
          next_id += 1
          steps << step
          step_samples[step.id] = sample
          state = next_state
        end

        run = Run.new(initial_state: initial_state, steps: steps.freeze)
        RunSample.new(
          run,
          initial_state_sample: initial_state_sample,
          step_samples: step_samples,
          session: ShrinkSession.new(max_attempts: @max_shrink_attempts)
        )
      end

      # Execute a `Run` against a fresh SUT with full lifecycle, verification, and invariants.
      #
      # @param run [Run]
      # @return [void]
      def run(run)
        sym_state = Resolver.deep_freeze(run.initial_state)
        env = {}
        resolved_initial = Resolver.resolve(sym_state, env)

        @spec.with_sut(resolved_initial) do |sut|
          check_invariants!(resolved_initial, sut, step_index: nil, step: nil)

          run.steps.each_with_index do |step, index|
            command = @spec.command_by_name(step.command)
            concrete_args = Resolver.resolve(step.args, env)

            result = execute_stage(stage: :run, target: command.name, step_index: index, step: step) do
              command.run!(sut, concrete_args)
            end

            after_sym = command.next_state(sym_state, step.args, Ref.new(step_id: step.id))
            env[step.id] = result

            before_concrete = Resolver.resolve(sym_state, env)
            after_concrete = Resolver.resolve(after_sym, env)

            context = Context.new(
              step: step,
              before: before_concrete,
              after: after_concrete,
              args: concrete_args,
              result: result,
              sut: sut
            )

            execute_stage(stage: :verify, target: command.name, step_index: index, step: step) do
              command.verify!(context)
            end

            check_invariants!(after_concrete, sut, step_index: index, step: step)
            sym_state = after_sym
          end
        end
      end

      # Deterministically replay a `Pbt::Stateful::Run` (e.g. `details.counterexample`).
      #
      # @param run [Run]
      # @return [void]
      def replay(run)
        unless run.is_a?(Run)
          raise ArgumentError, "replay expects a Pbt::Stateful::Run, got #{run.class}"
        end

        self.run(run)
      end

      # Determine whether a shrink candidate failure matches the original failure signature.
      #
      # @param initial_err [Exception]
      # @param candidate_err [Exception]
      # @return [Boolean]
      def same_failure?(initial_err, candidate_err)
        return false unless initial_err.is_a?(StepFailure) && candidate_err.is_a?(StepFailure)
        return false if initial_err.teardown_error

        initial_err.signature == candidate_err.signature
      end

      # Shrink a failing runner `Case` while preserving provenance and shared shrink session.
      #
      # @param test_case [Pbt::Check::Case]
      # @return [Enumerator<RunSample>]
      def shrink_case(test_case)
        return [].each if test_case.exception.is_a?(StepFailure) && test_case.exception.teardown_error

        run_sample =
          if test_case.sample.is_a?(RunSample)
            test_case.sample
          else
            RunSample.new(
              test_case.val,
              initial_state_sample: nil,
              step_samples: {},
              session: ShrinkSession.new(max_attempts: @max_shrink_attempts)
            )
          end

        @shrinker.shrink(run_sample, failure: test_case.exception)
      end

      # Plain-value shrink fallback yielding `Run` objects.
      #
      # @param run [Run]
      # @return [Enumerator<Run>]
      def shrink(run)
        run_sample = RunSample.new(
          run,
          initial_state_sample: nil,
          step_samples: {},
          session: ShrinkSession.new(max_attempts: @max_shrink_attempts)
        )
        Enumerator.new do |y|
          @shrinker.shrink(run_sample, failure: nil).each do |sample|
            y << sample.value
          end
        end
      end

      def run_in_ractor(_run)
        raise Pbt::InvalidConfiguration, "Pbt.stateful does not support worker: :ractor. Use worker: :none instead."
      end

      private

      def validate_options!(max_steps:, min_steps:, max_shrink_attempts:)
        unless min_steps.is_a?(Integer) && min_steps >= 0
          raise InvalidSpec, "min_steps must be a non-negative Integer, got #{min_steps.inspect}"
        end
        unless max_steps.is_a?(Integer) && max_steps >= min_steps
          raise InvalidSpec, "max_steps must be an Integer >= min_steps (#{min_steps}), got #{max_steps.inspect}"
        end
        unless max_shrink_attempts.is_a?(Integer) && max_shrink_attempts >= 0
          raise InvalidSpec, "max_shrink_attempts must be a non-negative Integer, got #{max_shrink_attempts.inspect}"
        end
      end

      def eligible_commands(state)
        @spec.commands.select { |cmd| cmd.guard?(state) }
      end

      # Returns `[step, sample, next_state]`, or `nil` if all eligible commands had empty domains.
      # Raises `GenerationError` if eligible commands had non-empty domains but preconditions never passed.
      def select_step(eligible, state, step_index, step_id, rng)
        candidates = eligible.dup
        attempts = 0

        while attempts < PER_STEP_MAX_ATTEMPTS && !candidates.empty?
          attempts += 1
          command = pick_weighted(candidates, rng)

          arb =
            begin
              command.arguments_for(state)
            rescue Pbt::Arbitrary::EmptyDomainError
              candidates.delete(command)
              next
            end

          sample =
            begin
              Pbt::Arbitrary::Sample.capture(arb, rng)
            rescue Pbt::Arbitrary::EmptyDomainError
              candidates.delete(command)
              next
            end

          if command.precondition?(state, sample.value)
            ref = Ref.new(step_id: step_id)
            next_state = command.next_state(state, sample.value, ref)
            step = Step.new(id: step_id, command: command.name, args: sample.value)
            return [step, sample, next_state]
          end
        end

        return nil if candidates.empty?

        raise GenerationError,
          "could not satisfy preconditions at step #{step_index} after #{PER_STEP_MAX_ATTEMPTS} attempts " \
          "(eligible: #{eligible.map(&:name).inspect})"
      end

      def pick_weighted(commands, rng)
        return commands.first if commands.size == 1

        total = commands.sum(&:weight)
        ticket = rng.rand(total)
        cumulative = 0
        commands.each do |cmd|
          cumulative += cmd.weight
          return cmd if ticket < cumulative
        end
        commands.last
      end

      def check_invariants!(state, sut, step_index:, step:)
        @spec.invariants.each do |inv|
          execute_stage(stage: :invariant, target: inv.name, step_index: step_index, step: step) do
            Resolver.invoke_with_arity(inv.block, state, sut)
          end
        end
      end

      def execute_stage(stage:, target:, step_index:, step:)
        yield
      rescue *Check::FATAL_EXCEPTIONS, InvalidSpec, ModelError, PreconditionNotMet
        raise
      rescue Exception => e # standard:disable Lint/RescueException
        step_label = step_index ? "step #{step_index + 1} #{step.format}" : "initial"
        target_label = (stage == :invariant && target) ? "invariant #{target.inspect}" : stage.to_s
        failure = StepFailure.new(
          "#{step_label} [#{target_label}]: #{e.message}",
          step_index: step_index,
          step: step,
          stage: stage,
          target: target,
          exception_class: e.class
        )
        failure.set_backtrace(e.backtrace) if e.backtrace
        raise failure
      end
    end
  end
end
