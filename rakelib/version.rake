VERSION_PATTERN = /VERSION\s*=\s*"(\d+\.\d+\.\d+)"/

VERSION_FILE = File.expand_path("../lib/codeball/version.rb", __dir__)

namespace :version do
  desc "Display the current version"
  task(:current) { print_current_version }

  desc "Bump the patch version"
  task(:bump) { bump_version(VERSION_FILE) }

  desc "Commit the version change"
  task(:commit) { commit_version(VERSION_FILE) }

  desc "Revert the last version bump commit"
  task(:revert) { revert_version_bump }
end

namespace :release do
  desc "Bump version, commit, and release"
  task full: ["version:bump", "version:commit", :release]
end

def print_current_version
  require_relative "../lib/codeball/version"
  puts "Current version: #{Codeball::VERSION}"
end

def commit_version(version_path)
  require_relative "../lib/codeball/version"
  sh "git add #{version_path}"
  sh "git commit -m 'Bump version to #{Codeball::VERSION}'"
  puts "Version change committed."
end

def bump_version(version_path)
  source = read_locked(version_path)
  match = source.match(VERSION_PATTERN)
  abort "Could not find VERSION in #{version_path}" unless match

  old_version = match[1]
  new_version = increment_patch(old_version)
  write_locked(version_path, source, old_version, new_version)
  puts "Version bumped from #{old_version} to #{new_version}"
end

def read_locked(path)
  File.open(path, "r") do |f|
    f.flock(File::LOCK_SH)
    f.read
  end
end

def write_locked(path, source, old_ver, new_ver)
  new_source = source.sub(
    /VERSION\s*=\s*"#{Regexp.escape(old_ver)}"/,
    "VERSION = \"#{new_ver}\"",
  )
  File.write(path, new_source)
end

def increment_patch(version)
  parts = version.split(".").map(&:to_i)
  parts[-1] += 1
  parts.join(".")
end

def revert_version_bump
  last_message = `git log -1 --pretty=%B`.strip
  if last_message.start_with?("Bump version to ")
    sh "git revert HEAD --no-edit"
    puts "Version bump reverted."
  else
    abort "Last commit does not appear to be a version bump."
  end
end
