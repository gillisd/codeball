require "command_kit/command"
require "command_kit/open"
require "command_kit/colors"

module Codeball
  module Commands
    # List files contained in a codeball.
    class Filter < CommandKit::Command
      include CommandKit::Open
      include CommandKit::Colors

      usage "[options] [FILE]"
      description "Filter entries in a codeball"

      option :inverse, short: "-v", desc: "Reverse direction of filtering"

      argument :patterns, required: true, repeats: true, desc: "Patterns to filter on"
      argument :file, required: false, desc: "Codeball file (or stdin if omitted)"

      examples ["bundle.txt", "< bundle.txt"]

      def env
        (super || {}).merge("TERM" => "1")
      end

      def run(*args)
        file = (
        if stdin.tty?
          args => [*patterns, path]
          path
        else
          args => [*patterns]
          "-"
        end
      )
        io = open file
        input = io.read

        abort_if_empty(input)

        ball = Ball.parse(input)

        ball.each_warning { |msg| stderr.puts colors.yellow("warning: #{msg}") }

        ball
          .each_entry
          .reject { match?(patterns, it) }
          .each { ball.remove_entry it }

        stdout.puts ball.serialize
      end

      private

      def match?(patterns, entry)
        verb = options[:inverse] ? :none? : :any?
        patterns.public_send(verb) { |pattern| File.fnmatch?(pattern, entry.path) }
      end

      def abort_if_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end
    end
  end
end
