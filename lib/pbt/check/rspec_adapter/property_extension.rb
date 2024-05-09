# frozen_string_literal: true

module Pbt
  module Check
    module RSpecAdapter
      # @private
      module PropertyExtension
        # Define an original class to be called in Ractor.
        #
        # @return [void]
        def setup_rspec_integration
          filepath, line = @predicate.source_location
          basename = File.basename(filepath, ".rb")
          @class_name = "Test" + basename.split("_").map(&:capitalize).join + line.to_s
          @method_name = "predicate_#{basename}_#{line}"
          define_ractor_callable_class
        end

        # Clean up an original class to be called in Ractor to avoid any persisted namespace pollution.
        #
        # @return [void]
        def teardown_rspec_integration
          RSpecAdapter.__send__(:remove_const, @class_name) if RSpecAdapter.const_defined?(@class_name)
        end

        # Run the predicate with the generated `val`.
        # This overrides the original `Property#run_in_ractor`.
        #
        # @param val [Object]
        # @return [Ractor]
        def run_in_ractor(val)
          Ractor.new(@class_name, @method_name, @predicate.parameters.size, val) do |class_name, method_name, param_size, val|
            klass = RSpecAdapter.const_get(class_name)
            if val.is_a?(Hash)
              klass.new.send(method_name, **val)
            elsif param_size >= 2
              klass.new.send(method_name, *val)
            else
              klass.new.send(method_name, val)
            end
          end
        end

        private

        # @return [void]
        def define_ractor_callable_class
          # The @method_name is invisible in the Class.new block, so we need to assign it to a local variable.
          method_name = @method_name

          inspector = extract_predicate_source_code

          RSpecAdapter.const_set(@class_name, Class.new do
            include ::RSpec::Matchers
            class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{method_name}(#{inspector.method_params})
              #{inspector.method_body}
            end
            RUBY
          end)
        end

        # @return [PredicateBlockInspector]
        def extract_predicate_source_code
          filepath, line = @predicate.source_location
          PredicateBlockInspector.new(line).tap do |inspector|
            res = Prism.parse_file(filepath)
            res.value.statements.accept(inspector)
          end
        end
      end
    end
  end
end
