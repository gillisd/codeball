require "command_kit/command"
require "command_kit/open"
require "command_kit/colors"

module Codeball
  module Commands
    # Filter entries in a codeball by glob pattern.
    class Filter < CommandKit::Command
      include CommandKit::Open
      include CommandKit::Colors

      usage "[options] [FILE]"
      description "Filter entries in a codeball"

      option :inverse, short: "-v", desc: "Reverse direction of filtering"

      # Flags chosen so glob semantics match what users expect from shell
      # globs: FNM_PATHNAME makes '*' stop at '/' and enables '**/' for
      # recursive matching; FNM_EXTGLOB enables '{rb,py}' brace expansion.
      FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

      argument :patterns, required: true, repeats: true, desc: "Patterns to filter on"
      argument :file, required: false, desc: "Codeball file (or stdin if omitted)"

      examples [
        "'*.rb' bundle.txt",
        "'*.rb' < bundle.txt",
        "'lib/**/*.rb' bundle.txt",
        "-v 'test/**' bundle.txt"
      ]

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

        ball.each_warning { |msg| stderr.puts colors(stderr).yellow("warning: #{msg}") }

        ball
          .each_entry
          .reject { match?(patterns, it) }
          .each { ball.remove_entry it }

        stdout.puts ball.serialize
      end

      private

      def match?(patterns, entry)
        verb = options[:inverse] ? :none? : :any?
        patterns.public_send(verb) { |pattern| File.fnmatch?(pattern, entry.path, FNMATCH_FLAGS) }
      end

      def abort_if_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end
    end
  end
end
