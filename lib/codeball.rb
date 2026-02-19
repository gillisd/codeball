require_relative "codeball/version"
require_relative "codeball/error"
require_relative "codeball/config"
require_relative "codeball/extraction_result"
require_relative "codeball/extraction_summary"
require_relative "codeball/entry"
require_relative "codeball/bundle"


# CLI requires command_kit gem - only load if available
begin
  require 'command_kit'
  require_relative "codeball/cli"
rescue LoadError
  # command_kit not installed, CLI unavailable
end
