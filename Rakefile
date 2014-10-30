require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new

task :test => :spec

task :clean do
    rm_rf 'pkg'
end

