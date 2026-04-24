# encoding: utf-8
require "logstash/devutils/rake"
require "jars/installer"
require "fileutils"

task :default do
  system('rake -vT')
end

task :vendor do
  exit(1) unless system './gradlew vendor'
end

task :clean do
  ["vendor/jar-dependencies", "Gemfile.lock"].each do |p|
    FileUtils.rm_rf(p)
  end
end

require "rspec/core/rake_task"

namespace :spec do
  desc "Run integration specs (uses in-process gRPC fake, no emulator needed)"
  RSpec::Core::RakeTask.new(:integration) do |t|
    t.pattern = "spec/integration/**/*_spec.rb"
    t.rspec_opts = "--tag integration"
  end
end

