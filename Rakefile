# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]

namespace :benchmark do
  task all: ["success:simple", "success:cpu_bound", "success:io_bound", "failure:simple"]

  namespace :success do
    task :simple do
      puts "### Benchmark success:simple"
      puts
      puts "This runs a script that does not do any IO or CPU bound work."
      puts
      ENV["RUBYOPT"] = "-W:no-experimental"
      ENV["RUBY_MN_THREADS"] = "1"
      puts "```"
      sh "ruby", "benchmark/success_simple.rb"
      puts "```"
      puts
    end

    task :cpu_bound do
      puts "### Benchmark success:cpu_bound"
      puts
      puts "This runs a script that does CPU bound work."
      puts
      ENV["RUBYOPT"] = "-W:no-experimental"
      ENV["RUBY_MN_THREADS"] = "1"
      puts "```"
      sh "ruby", "benchmark/success_cpu_bound.rb"
      puts "```"
      puts
    end

    task :io_bound do
      puts "### Benchmark success:io_bound"
      puts
      puts "This runs a script that does IO bound work."
      puts
      ENV["RUBYOPT"] = "-W:no-experimental"
      ENV["RUBY_MN_THREADS"] = "1"
      puts "```"
      sh "ruby", "benchmark/success_io_bound.rb"
      puts "```"
      puts
    end
  end

  namespace :failure do
    task :simple do
      puts "### Benchmark failure:simple"
      puts
      puts "This runs a script that fails and shrink happens."
      puts
      ENV["RUBYOPT"] = "-W:no-experimental"
      ENV["RUBY_MN_THREADS"] = "1"
      puts "```"
      sh "ruby", "benchmark/failure_simple.rb"
      puts "```"
      puts
    end
  end
end
