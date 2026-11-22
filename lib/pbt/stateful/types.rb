# frozen_string_literal: true

module Pbt
  module Stateful
    # Opaque symbolic token referencing the return value of an earlier step with `id == step_id`.
    Ref = Data.define(:step_id) do
      def to_s
        "v#{step_id}"
      end

      alias_method :inspect, :to_s
    end

    # Immutable record of a single generated command step.
    Step = Data.define(:id, :command, :args) do
      def format(assign: false)
        call = args.nil? ? command.to_s : "#{command}(#{Resolver.format_value(args)})"
        assign ? "v#{id} = #{call}" : call
      end

      def to_s
        format
      end
    end

    # Pure, immutable representation of a generated stateful test run.
    Run = Data.define(:initial_state, :steps) do
      def size
        steps.size
      end

      def empty?
        steps.empty?
      end

      def command_names
        steps.map(&:command)
      end

      def format(failed_step_index: nil, failed_stage: nil)
        referenced_ids = Resolver.referenced_step_ids(steps)
        lines = ["initial_state: #{Resolver.format_value(initial_state)}"]
        if steps.empty?
          lines << "(no steps)"
        else
          steps.each_with_index do |step, idx|
            line = "#{idx + 1}. #{step.format(assign: referenced_ids.include?(step.id))}"
            if failed_step_index == idx && failed_stage
              line = "#{line}  # <- failed (#{failed_stage})"
            end
            lines << line
          end
        end
        lines.join("\n")
      end

      def to_s
        format
      end

      alias_method :inspect, :to_s
    end

    # Concrete execution context passed to `c.verify`.
    Context = Data.define(:step, :before, :after, :args, :result, :sut)

    # Helpers for resolving symbolic Refs, traversing containers, and deep-freezing model states.
    module Resolver
      module_function

      # Return whether `obj` is a Pbt arbitrary (explicitly avoiding false positives like `Array#sample`).
      #
      # @param obj [Object]
      # @return [Boolean]
      def arbitrary?(obj)
        obj.is_a?(Pbt::Arbitrary::Arbitrary) || (obj.respond_to?(:generate) && obj.respond_to?(:shrink))
      end

      # Deep-duplicate standard value containers and mutable Strings while preserving cycles and opaque objects.
      #
      # @param obj [Object]
      # @param cache [Hash]
      # @return [Object]
      def deep_dup(obj, cache = {}.compare_by_identity)
        return cache[obj] if cache.key?(obj)

        case obj
        when String
          obj.dup
        when Array
          res = []
          cache[obj] = res
          obj.each { |elem| res << deep_dup(elem, cache) }
          res
        when Hash
          res = {}
          cache[obj] = res
          obj.each { |k, v| res[deep_dup(k, cache)] = deep_dup(v, cache) }
          res
        when Set
          res = Set.new
          cache[obj] = res
          obj.each { |elem| res << deep_dup(elem, cache) }
          res
        when Struct
          res = obj.dup
          cache[obj] = res
          obj.members.each { |member| res[member] = deep_dup(obj[member], cache) }
          res
        when Data
          members = obj.to_h
          members.empty? ? obj : obj.with(**members.transform_values { |v| deep_dup(v, cache) })
        else
          obj
        end
      end

      # Resolve symbolic `Ref` tokens into concrete SUT return values inside standard value containers.
      # When `detach: true`, mutable Strings and frozen Structs in symbolic values are duplicated so SUT
      # mutations never corrupt immutable `Run`/`Step` values or trigger `FrozenError`, while concrete
      # `Ref` targets from `env` retain their exact object identity.
      #
      # @param obj [Object]
      # @param env [Hash{Integer => Object}]
      # @param detach [Boolean]
      # @param cache [Hash]
      # @return [Object]
      def resolve(obj, env, detach: false, cache: {}.compare_by_identity)
        return cache[obj] if cache.key?(obj)

        case obj
        when Ref
          env.fetch(obj.step_id)
        when String
          detach ? obj.dup : obj
        when Array
          res = []
          cache[obj] = res
          obj.each { |elem| res << resolve(elem, env, detach: detach, cache: cache) }
          res
        when Hash
          res = {}
          cache[obj] = res
          obj.each do |k, v|
            res[resolve(k, env, detach: detach, cache: cache)] = resolve(v, env, detach: detach, cache: cache)
          end
          res
        when Set
          res = Set.new
          cache[obj] = res
          obj.each { |elem| res << resolve(elem, env, detach: detach, cache: cache) }
          res
        when Struct
          copy = obj.dup
          cache[obj] = copy
          obj.members.each { |member| copy[member] = resolve(obj[member], env, detach: detach, cache: cache) }
          (!detach && obj.frozen?) ? copy.freeze : copy
        when Data
          members = obj.to_h
          members.empty? ? obj : obj.with(**members.transform_values { |v| resolve(v, env, detach: detach, cache: cache) })
        else
          obj
        end
      end

      # Collect all `Ref` step IDs reachable inside standard value containers.
      #
      # @param obj [Object]
      # @param ids [Set<Integer>]
      # @param visited [Hash]
      # @return [Set<Integer>]
      def collect_ref_ids(obj, ids = Set.new, visited = {}.compare_by_identity)
        return ids if visited.key?(obj)

        case obj
        when Ref
          ids << obj.step_id
        when Array
          visited[obj] = true
          obj.each { |elem| collect_ref_ids(elem, ids, visited) }
        when Hash
          visited[obj] = true
          obj.each do |k, v|
            collect_ref_ids(k, ids, visited)
            collect_ref_ids(v, ids, visited)
          end
        when Set
          visited[obj] = true
          obj.each { |elem| collect_ref_ids(elem, ids, visited) }
        when Struct
          visited[obj] = true
          obj.members.each { |member| collect_ref_ids(obj[member], ids, visited) }
        when Data
          visited[obj] = true
          obj.to_h.each_value { |v| collect_ref_ids(v, ids, visited) }
        end
        ids
      end

      # Collect all `Ref` step IDs referenced across a step array's arguments.
      #
      # @param steps [Array<Step>]
      # @return [Set<Integer>]
      def referenced_step_ids(steps)
        ids = Set.new
        steps.each { |step| collect_ref_ids(step.args, ids) }
        ids
      end

      # Format a value for counterexample traces, rendering `Ref` as `v<id>`.
      #
      # @param obj [Object]
      # @param visited [Hash]
      # @return [String]
      def format_value(obj, visited = {}.compare_by_identity)
        case obj
        when Ref
          obj.to_s
        when Array
          return "[...]" if visited.key?(obj)

          visited[obj] = true
          begin
            "[#{obj.map { |e| format_value(e, visited) }.join(", ")}]"
          ensure
            visited.delete(obj)
          end
        when Hash
          return "{...}" if visited.key?(obj)

          visited[obj] = true
          begin
            pairs = obj.map do |k, v|
              key_str = k.is_a?(Symbol) ? "#{k}:" : "#{format_value(k, visited)} =>"
              "#{key_str} #{format_value(v, visited)}"
            end
            "{#{pairs.join(", ")}}"
          ensure
            visited.delete(obj)
          end
        when Set
          return "Set[...]" if visited.key?(obj)

          visited[obj] = true
          begin
            "Set[#{obj.map { |e| format_value(e, visited) }.join(", ")}]"
          ensure
            visited.delete(obj)
          end
        else
          obj.inspect
        end
      end

      # Deep-freeze model state to detect accidental mutation immediately.
      #
      # @param obj [Object]
      # @return [Object]
      def deep_freeze(obj)
        Ractor.make_shareable(obj)
      rescue Ractor::Error
        fallback_freeze(obj, {}.compare_by_identity)
      end

      # Invoke a Proc/lambda with only as many positional arguments as it accepts.
      #
      # @param callable [#call, #parameters]
      # @param args [Array<Object>]
      # @return [Object]
      def invoke_with_arity(callable, *args)
        params = callable.respond_to?(:parameters) ? callable.parameters : nil
        return callable.call(*args) unless params

        return callable.call(*args) if params.any? { |type, _| type == :rest }

        max_positional = params.count { |type, _| type == :req || type == :opt }
        callable.call(*args.first(max_positional))
      end

      def fallback_freeze(obj, visited)
        return obj if visited.key?(obj)

        visited[obj] = true
        case obj
        when Array
          obj.each { |elem| fallback_freeze(elem, visited) }
        when Hash
          obj.each do |k, v|
            fallback_freeze(k, visited)
            fallback_freeze(v, visited)
          end
        when Set
          obj.each { |elem| fallback_freeze(elem, visited) }
        when Struct
          obj.members.each { |member| fallback_freeze(obj[member], visited) }
        when Data
          obj.to_h.each_value { |v| fallback_freeze(v, visited) }
        end
        obj.freeze
      end
      private_class_method :fallback_freeze
    end
  end
end
