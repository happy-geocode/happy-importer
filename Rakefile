require "bundler/gem_tasks"

Dir.glob('lib/tasks/*.rake').each { |r| import r }

require "rspec"
require "rspec/core/rake_task"

namespace :spec do
desc "Acceptance Tests"
RSpec::Core::RakeTask.new(:unit) do |spec|
  spec.pattern = "spec/unit/*_spec.rb"
end
end

task :default => ["spec:unit"]
