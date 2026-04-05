require "command_kit"
require "command_kit/command"
require "command_kit/colors"

module Codeball
  module Commands
    # Diff extracted files against local copies.
    #
    # Incomplete -- diff output is not yet implemented.
    #
    class Diff < CommandKit::Command
      include CommandKit::Colors

      usage "[options] [FILE]"
      description "Diff codeball entries against local files"

      option :output_dir, short: "-o",
                          value: { type: String, default: "." },
                          desc: "Directory to compare against"

      argument :file, required: false,
                      desc: "Codeball file (or stdin if omitted)"

      examples [
        "bundle.txt",
        "< bundle.txt",
      ]

      def run(file = nil)
        input = read_input(file)
        ball = Ball.parse(input)

        ball.each_parse_warning { |msg| stderr.puts colors.yellow("warning: #{msg}") }

        # Diff output not yet implemented
      end

      private

      def read_input(file)
        ARGV.replace(file ? [file] : [])
        input = ARGF.read

        return input unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end
    end
  end
end
