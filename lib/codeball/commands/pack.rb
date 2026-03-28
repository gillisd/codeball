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

      option :border, short: "-b",
                      value: { type: String, default: "---\t" },
                      desc: "The border pattern repeated between sections."

      option :border_width, short: "-w",
                            value: { type: Integer, default: 10 },
                            desc: "How many times to repeat the border pattern"

      option :quiet, short: "-q", long: "--quiet", desc: "Suppress non-error output"

      argument :files, required: true,
                       repeats: true,
                       desc: "Files to pack into bundle"

      examples [
        "lib/*.rb",
        "src/**/*.py --border '###'",
        "-w 5 README.md lib/*.rb",
      ]

      def run(*files)
        if files.empty?
          print_error "no files specified"
          exit 1
        end

        readable, unreadable = validate_files(files)
        bundle = Bundle.from_files(readable, config: build_config)

        warn_skipped(unreadable, bundle.non_text_entries)
        bundle.serialize

        exit 1 if unreadable.any? || bundle.non_text_entries.any?
      end

      private

      def build_config
        Config.new(
          border: options[:border],
          border_width: options[:border_width],
          output_dir: ".",
          dry_run: false,
        )
      end

      def validate_files(files)
        files
          .map { Pathname(it) }
          .partition { it.exist? && it.readable? }
      end

      def warn_skipped(unreadable, non_text)
        return if options[:quiet]

        unreadable.each { print_error "cannot read file: #{it}" }
        non_text.each { print_error "skipping non-text file: #{it.path} (#{it.mime_type})" }
      end
    end
  end
end
