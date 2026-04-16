require "command_kit/command"
require "command_kit/colors"
require 'command_kit/open'

module Codeball
  module Commands
    # Extract files from a codeball.
    #
    class Unpack < CommandKit::Command
      include CommandKit::Colors
      include CommandKit::Open

      usage "[options] [FILE]"
      description "Extract files from a codeball"

      option :output_dir, short: "-o",
                          value: { type: String, default: "." },
                          desc: "Output directory"

      option :stdout, short: '-O', desc: "Write file contents to stdout instead of to files. (Analagous to tar -Ox)"
      option :dry_run, short: "-n",
                       desc: "Preview extraction without writing files"

      option :quiet, short: "-q", long: "--quiet", desc: "Suppress non-error output"

      argument :file, required: false,
                      desc: "Codeball file (or stdin if omitted)"

      examples [
        "bundle.txt",
        "-n bundle.txt",
        "-o extracted/ bundle.txt",
        "< bundle.txt",
      ]

      def run(file = '-')
        ball = read_input(file)
                 .then { Ball.parse(it) }

        ball.each_warning { |msg| warn colors.yellow("warning: #{msg}") }

        if options[:stdout]
          ball.each_entry { stdout.puts it.body }
          return
        end

        dest = build_destination

        ball.each_entry { |entry| dest.write(entry) { |outcome| print_outcome(outcome) } }

        print_summary(dest.summary(malformed: ball.warning_count))
      end

      private

      def build_destination
        Destination.new(options[:output_dir], dry_run: options[:dry_run])
      end

      def read_input(file)
        input = open(file).read
        abort_on_empty(input)
        input
      end

      def abort_on_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end

      def puts(...)
        return if options[:quiet]

        stdout.puts(...)
      end

      def warn(...)
        return if options[:quiet]

        stderr.puts(...)
      end

      def print_outcome(outcome)
        case outcome.status
        when :written then print_written(outcome)
        when :dry_run then print_dry_run(outcome)
        when :unsafe  then print_unsafe(outcome)
        when :failed  then print_failed(outcome)
        end
      end

      def print_written(outcome)
        puts "#{colors.green("wrote")}: #{outcome.path} (#{outcome.line_count} lines)"
      end

      def print_dry_run(outcome)
        puts "#{colors.cyan("[dry-run]")} would write: #{outcome.path} (#{outcome.line_count} lines)"
      end

      def print_unsafe(outcome)
        warn colors.yellow("warning: skipping unsafe path #{outcome.path.inspect}")
      end

      def print_failed(outcome)
        warn colors.red("error: #{outcome.path}: #{outcome.error}")
      end

      def print_summary(summary)
        prefix = summary.dry_run? ? "#{colors.cyan("[dry-run]")} " : ""
        puts "---"
        puts "#{prefix}#{summary_parts(summary).join(", ")}"
      end

      def summary_parts(summary)
        parts = [colors.green("extracted: #{summary.extracted}").to_s]
        parts << skipped_part(summary)
        parts << colors.yellow("malformed: #{summary.malformed}") if summary.malformed.positive?
        parts
      end

      def skipped_part(summary)
        if summary.skipped.positive?
          colors.yellow("skipped: #{summary.skipped}")
        else
          "skipped: 0"
        end
      end
    end
  end
end
