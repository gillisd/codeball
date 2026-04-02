require "warning"
require "zeitwerk"

##
# Bidirectional file bundler for clipboard-friendly LLM workflows.
#
# Packs multiple source files into a single plaintext bundle and extracts
# them back to disk.  Uses Zeitwerk for autoloading.
module Codeball
  LOADER = Zeitwerk::Loader.for_gem
  LOADER.inflector.inflect("cli" => "CLI")
  LOADER.setup

  # CLI requires command_kit gem - only load if available
  begin
    require "command_kit"
    require_relative "codeball/cli"
    Warning.ignore(/FileMagic/)
  rescue LoadError
    # command_kit not installed, CLI unavailable
  end
end
