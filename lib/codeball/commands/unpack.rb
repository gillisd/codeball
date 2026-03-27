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

      option :quiet, short: '-q', long: '--quiet', desc: "Suppress non-error output"

      argument :file, required: false,
                      desc: "Bundle file (or stdin if omitted)"

      examples [
        "bundle.txt",
        "-n bundle.txt",
        "-o extracted/ bundle.txt",
        "< bundle.txt"
      ]

      def run(file = nil)
        config = Config.new(
          border:       options[:border],
          border_width: options[:border_width],
          output_dir:   options[:output_dir],
          dry_run:      options[:dry_run] || false
        )

        ARGV.replace(file ? [file] : [])
        input = ARGF.read

        if input.nil? || input.strip.empty?
          print_error "no input"
          exit 1
        end

        bundle = Bundle.parse(input, config: config)

        # Print parse warnings
        bundle.parse_errors.each do |msg|
          warn colors.yellow("warning: #{msg}")
        end

        # Extract and print results
        summary = bundle.extract
        print_results(summary.results, config.dry_run)
        print_summary(summary, config.dry_run)
      end

      private

      def puts(...)
        return if options[:quiet]
        stdout.puts(...)
      end

      def warn(...)
        return if options[:quiet]
        stderr.puts(...)
      end

      def print_results(results, dry_run)
        results.each do |result|
          case result.status
          when :written
            puts "#{colors.green('wrote')}: #{result.path} (#{result.size} lines)"
          when :dry_run
            puts "#{colors.cyan('[dry-run]')} would write: #{result.path} (#{result.size} lines)"
          when :unsafe
            warn colors.yellow("warning: skipping unsafe path #{result.path.inspect}")
          when :failed
            warn colors.red("error: #{result.path}: #{result.error}")
          end
        end
      end

      def print_summary(summary, dry_run)
        prefix = dry_run ? "#{colors.cyan('[dry-run]')} " : ""
        puts "---"

        parts = []
        parts << "#{colors.green("extracted: #{summary.extracted}")}"
        parts << (summary.skipped > 0 ? colors.yellow("skipped: #{summary.skipped}") : "skipped: 0")
        parts << colors.yellow("malformed: #{summary.malformed}") if summary.malformed > 0

        puts "#{prefix}#{parts.join(', ')}"
      end
    end
  end
end
