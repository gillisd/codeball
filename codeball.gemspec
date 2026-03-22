require_relative "lib/codeball/version"

Gem::Specification.new do |spec|
  spec.name = "codeball"
  spec.version = Codeball::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Bidirectional file bundler for clipboard-friendly LLM workflows"
  spec.description = "Pack multiple source files into a single plaintext bundle for " \
                     "pasting into LLM context windows, then unpack the response back into files."
  spec.homepage = "https://github.com/yourusername/codeball"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  spec.files = Dir.glob(%w[lib/**/*.rb bin/* LICENSE.txt README.md])
  spec.bindir = "bin"
  spec.executables = ["codeball"]
  spec.require_paths = ["lib"]

  spec.add_dependency "command_kit", "~> 0.6"
end
