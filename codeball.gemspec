require_relative "lib/codeball/version"

Gem::Specification.new do |spec|
  spec.name = "codeball"
  spec.version = Codeball::VERSION
  spec.authors = ["David Gillis"]
  spec.email = ["david@flipmine.com"]
  spec.summary = "Bidirectional file packer for clipboard-friendly LLM workflows"
  spec.description = "Pack multiple source files into a single plaintext codeball for " \
                     "pasting into LLM context windows, then unpack the response back into files."
  spec.homepage = "https://github.com/gillisd/codeball"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  gemspec_file = File.basename(__FILE__)
  files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) { |ls|
    ls.readlines(0.chr, chomp: true).reject do |f|
      (f == gemspec_file) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", "Gemfile")
    end
  }
  files = Dir.glob("{lib,exe,rakelib}/**/*").push("README.md", "LICENSE.txt", "Rakefile") if files.empty?
  spec.files = files
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "command_kit", "~> 0.6"
  spec.add_dependency "zeitwerk"
  spec.add_dependency "warning"
  spec.metadata["rubygems_mfa_required"] = "true"
end
