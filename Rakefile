require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"

Minitest::TestTask.create
RuboCop::RakeTask.new

namespace :zeitwerk do
  desc "Verify all files follow Zeitwerk naming conventions"
  task :validate do
    ruby "-e", <<~RUBY
      require 'codeball'
      Codeball::LOADER.eager_load(force: true)
      puts 'Zeitwerk: All files loaded successfully.'
    RUBY
  end
end

task default: [:test, :rubocop]
