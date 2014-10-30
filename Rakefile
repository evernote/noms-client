require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new

task :test => [:spec, :testcmd]

task :testcmd do
    ENV['RUBYLIB'] = ['lib', ENV['RUBYLIB']].join(':')
    ENV['PATH'] = ['bin', ENV['PATH']].join(':')
    Dir.new('spec').each do |script|
        next unless script =~ /\.sh$/
        puts script
        system(File.join('spec', script))
    end
end

task :clean do
    rm_rf 'pkg' 'test'
end

