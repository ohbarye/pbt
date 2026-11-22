# frozen_string_literal: true

require "spec_helper"
require "rbs"

RSpec.describe "RBS signatures in sig/" do
  let(:env) do
    loader = RBS::EnvironmentLoader.new
    loader.add(path: Pathname(File.expand_path("../sig", __dir__)))
    loader.add(library: "date")
    loader.add(library: "set") if RBS::Repository.default.lookup("set", nil)
    RBS::Environment.from_loader(loader).resolve_type_names
  end

  it "resolves all declared Pbt classes, modules, and interfaces without errors" do
    builder = RBS::DefinitionBuilder.new(env: env)
    pbt_decls = env.class_decls.select { |name, _| name.to_s.start_with?("::Pbt") }
    expect(pbt_decls).not_to be_empty

    pbt_decls.each_key do |type_name|
      builder.build_instance(type_name)
      builder.build_singleton(type_name)
    end

    pbt_interfaces = env.interface_decls.select { |name, _| name.to_s.start_with?("::Pbt") }
    pbt_interfaces.each_key do |type_name|
      builder.build_interface(type_name)
    end
  end

  it "matches existing Ruby classes, modules, and declared public methods" do
    builder = RBS::DefinitionBuilder.new(env: env)
    pbt_decls = env.class_decls.select { |name, _| name.to_s.start_with?("::Pbt") }

    pbt_decls.each_key do |type_name|
      mod = Object.const_get(type_name.to_s)

      singleton_def = builder.build_singleton(type_name)
      singleton_def.methods.each do |method_name, method_def|
        next unless method_def.defined_in == type_name && method_def.public?
        next if method_name == :new

        expect(mod).to respond_to(method_name), "Expected #{type_name}.#{method_name} to exist"
      end

      instance_def = builder.build_instance(type_name)
      instance_def.methods.each do |method_name, method_def|
        next unless method_def.defined_in == type_name && method_def.public?
        next if method_name == :initialize

        expect(mod.instance_methods(true)).to include(method_name), "Expected #{type_name}##{method_name} to exist"
      end
    end
  end
end
