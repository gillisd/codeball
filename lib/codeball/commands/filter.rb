require "command_kit/command"
require "command_kit/colors"

module Codeball
  module Commands
    # Filter entries in a codeball by glob pattern.
    class Filter < CommandKit::Command
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
        "-v 'test/**' bundle.txt",
      ]

      def run(*args)
        patterns, file = split_source(args)
        ball = Ball.parse(read_input(file))
        report_warnings(ball)
        drop_unmatched(ball, patterns)
        stdout.puts ball.serialize
      end

      private

      # The trailing argument is the codeball file when it names a readable
      # file on disk; otherwise every argument is a pattern and the ball is
      # read from stdin. This behaves the same interactively and in pipes.
      def split_source(args)
        *leading, last = args
        last && File.file?(last) ? [leading, last] : [args, nil]
      end

      def read_input(file)
        input = file ? File.read(file) : stdin.read
        abort_if_empty(input)
        input
      end

      def report_warnings(ball)
        ball.each_warning { |msg| stderr.puts colors(stderr).yellow("warning: #{msg}") }
      end

      def drop_unmatched(ball, patterns)
        ball.each_entry.reject { match?(patterns, it) }.each { ball.remove_entry(it) }
      end

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
