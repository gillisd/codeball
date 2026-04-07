require "command_kit/commands/command"
require "command_kit/printing/tables"
require "command_kit/colors"
require_relative "../../command_kit/printing"
require_relative "../../command_kit/combined_io"

module Codeball
  module Commands
    # List files contained in a codeball.
    class List < CommandKit::Commands::Command
      include CommandKit::CombinedIO
      include CommandKit::Colors
      include CommandKit::Printing::Tables

      usage "[options] [FILE]"
      description "List files in a codeball"

      argument :file, required: false, desc: "Codeball file (or stdin if omitted)"

      examples ["bundle.txt", "< bundle.txt"]

      def env
        (super || {}).merge("TERM" => "1")
      end

      def run(io)
        input = io.read
        abort_if_empty(input)

        ball = Ball.parse(input)

        ball.each_warning { |msg| stderr.puts colors.yellow("warning: #{msg}") }

        rows = []
        ball.each_entry { |e| rows << [e.path, "#{e.line_count} lines"] }
        print_table_color(rows, header: %w[File Lines], color: :green, index: 0)
      end

      private

      def abort_if_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end
    end
  end
end
