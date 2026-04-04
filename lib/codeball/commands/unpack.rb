require "command_kit/commands/command"
require "command_kit/colors"

module Codeball
  module Commands
    # Extract files from a codeball bundle.
    #
    class Unpack < CommandKit::Commands::Command
      include CommandKit::Colors

      usage "[options] [FILE]"
      description "Extract files from a bundle"

      option :border, short: "-b",
                      value: { type: String, default: "---\t" },
                      desc: "Border pattern"

      option :border_width, short: "-w",
                            value: { type: Integer, default: 10 },
                            desc: "Border repetitions"

      option :output_dir, short: "-o",
                          value: { type: String, default: "." },
                          desc: "Output directory"

      option :dry_run, short: "-n",
                       desc: "Preview extraction without writing files"

      option :quiet, short: "-q", long: "--quiet", desc: "Suppress non-error output"

      argument :file, required: false,
                      desc: "Bundle file (or stdin if omitted)"

      examples [
        "bundle.txt",
        "-n bundle.txt",
        "-o extracted/ bundle.txt",
        "< bundle.txt",
      ]

      def run(file = nil)
        config = build_config
        input = read_input(file)
        bundle = Bundle.parse(input, config: config)

        print_parse_warnings(bundle.parse_errors)

        summary = bundle.extract
        print_results(summary.results, config.dry_run)
        print_summary(summary, config.dry_run)
      end

      private

      def build_config
        Config.new(
          border: options[:border],
          border_width: options[:border_width],
          output_dir: options[:output_dir],
          dry_run: options[:dry_run] || false,
        )
      end

      def read_input(file)
        ARGV.replace(file ? [file] : [])
        input = ARGF.read

        abort_on_empty(input)
        input
      end

      def abort_on_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end

      def print_parse_warnings(errors)
        errors.each do |msg|
          warn colors.yellow("warning: #{msg}")
        end
      end

      def puts(...)
        return if options[:quiet]

        stdout.puts(...)
      end

      def warn(...)
        return if options[:quiet]

        stderr.puts(...)
      end

      def print_results(results, dry_run)
        results.each { |result| print_single_result(result, dry_run) }
      end

      def print_single_result(result, _dry_run)
        case result.status
        when :written  then print_written(result)
        when :dry_run  then print_dry_run(result)
        when :unsafe   then print_unsafe(result)
        when :failed   then print_failed(result)
        end
      end

      def print_written(result)
        puts "#{colors.green("wrote")}: #{result.path} (#{result.line_count} lines)"
      end

      def print_dry_run(result)
        puts "#{colors.cyan("[dry-run]")} would write: #{result.path} (#{result.line_count} lines)"
      end

      def print_unsafe(result)
        warn colors.yellow("warning: skipping unsafe path #{result.path.inspect}")
      end

      def print_failed(result)
        warn colors.red("error: #{result.path}: #{result.error}")
      end

      def print_summary(summary, dry_run)
        prefix = dry_run ? "#{colors.cyan("[dry-run]")} " : ""
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
