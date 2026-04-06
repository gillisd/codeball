require "command_kit/commands/command"

module Codeball
  module Commands
    # Pack files into a codeball for clipboard transfer.
    #
    class Pack < CommandKit::Commands::Command
      usage "[options] FILE..."

      description "Pack files into a codeball for clipboard transfer"

      option :quiet, short: "-q", long: "--quiet", desc: "Suppress non-error output"

      argument :files, required: true,
                       repeats: true,
                       desc: "Files to pack"

      examples [
        "lib/*.rb",
        "src/**/*.py",
        "README.md lib/*.rb",
      ]

      def run(*files)
        readable, unreadable = validate_files(files)
        ball = Ball.new
        readable.each do |path|
          entry = Entry.from_file(path)
          ball.add_entry(entry) if entry
        end

        warn_skipped(unreadable, ball)
        puts ball.serialize

        exit 1 if unreadable.any? || !ball.all_text?
      end

      private

      def validate_files(files)
        files
          .map { Pathname(it) }
          .partition { it.exist? && it.readable? }
      end

      def warn_skipped(unreadable, ball)
        return if options[:quiet]

        unreadable.each { print_error "cannot read file: #{it}" }
        ball.each_non_text_entry { |entry| print_error "skipping non-text file: #{entry.path} (#{entry.mime_type})" }
      end
    end
  end
end
