require "command_kit/commands/command"

module Codeball
  module Commands
    # Pack multiple files into a single clipboard-friendly bundle.
    #
    # Reads files from disk and serializes them into a bordered text format
    # suitable for pasting into LLM context windows.
    #
    class Pack < CommandKit::Commands::Command

      usage "[options] FILE..."

      description "Bundle files into a single stream for clipboard transfer"

      # The border pattern repeated between sections.
      # Default uses tabs which survive most clipboard operations.
      option :border, short: "-b",
                      value: { type: String, default: "---\t" },
                      desc: "Border pattern"

      # How many times to repeat the border pattern.
      option :border_width, short: "-w",
                            value: { type: Integer, default: 10 },
                            desc: "Border repetitions"

      # Files to pack into the bundle.
      argument :files, required: true,
                       repeats: true,
                       desc: "Files to bundle"

      examples [
        "lib/*.rb",
        "src/**/*.py --border '###'",
        "-w 5 README.md lib/*.rb"
      ]

      def run(*files)
        if files.empty?
          print_error "no files specified"
          exit 1
        end

        config = Config.new(
          border:       options[:border],
          border_width: options[:border_width],
          output_dir:   ".",
          dry_run:      false
        )

        Bundle.from_files(files, config: config).serialize
      end
    end
  end
end
