require "command_kit/commands"
require "command_kit/commands/auto_load"

module Codeball
  # Main CLI entry point for Codeball.
  #
  # Uses command_kit's Commands module to provide a git-style subcommand
  # interface with automatic help generation and option parsing.
  #
  class CLI
    include CommandKit::Commands
    include CommandKit::Description

    # Auto-load subcommands from lib/codeball/commands/*.rb
    include CommandKit::Commands::AutoLoad.new(
      dir:       File.join(__dir__, "commands"),
      namespace: "Codeball::Commands"
    )

    command_name "codeball"
    description "Bidirectional file bundler for clipboard-friendly LLM workflows"

#    examples [
#      "pack lib/*.rb test/*.rb | pbcopy",
#      "pbpaste | unpack -o extracted/",
#      "pack --border '###' src/**/*.py",
#      "unpack --dry-run < bundle.txt"
#    ]
  end
end
