require "command_kit/commands"
require "command_kit/commands/auto_load"
require "command_kit/options/version"

module Codeball
  # Main CLI entry point for Codeball.
  #
  class CLI
    include CommandKit::Commands
    include CommandKit::Description
    include CommandKit::Options::Version

    version Codeball::VERSION

    # Auto-load subcommands from lib/codeball/commands/*.rb
    include CommandKit::Commands::AutoLoad.new(
      dir: File.join(__dir__, "commands"),
      namespace: "Codeball::Commands",
    )

    command_name "codeball"
    description "Bidirectional file bundler for clipboard-friendly LLM workflows"
  end
end
