require "command_kit"
require "command_kit/command"
require "command_kit/colors"

module Codeball
  module Commands
    # Extract files from a codeball bundle.
    #
    class Diff < CommandKit::Command
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

      argument :file, required: false,
                      desc: "Bundle file (or stdin if omitted)"

      examples [
        "bundle.txt",
        "-n bundle.txt",
        "< bundle.txt"
      ]

      def run(file = nil)
        config = Config.new(
          border: options[:border],
          border_width: options[:border_width]
        )

        ARGV.replace(file ? [file] : [])
        input = ARGF.read

        if input.nil? || input.strip.empty?
          print_error "no input"
        end

        bundle = Bundle.parse(input, config: config)

        # Print parse warnings
        bundle.parse_errors.each do |msg|
          stderr.puts colors.yellow("warning: #{msg}")
        end

        # Extract and print results
        summary = bundle.extract
        print_results(summary.results, config.dry_run)
        print_summary(summary, config.dry_run)
      end
    end
  end
end
