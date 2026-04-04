require "command_kit/commands/command"
require "command_kit/printing/tables"
require "command_kit/colors"
require_relative "../../command_kit/printing"
require_relative "../../command_kit/combined_io"

module Codeball
  module Commands
    # Lists files contained in a codeball bundle.
    class List < CommandKit::Commands::Command
      include CommandKit::CombinedIO
      include CommandKit::Colors
      include CommandKit::Printing::Tables

      usage "[options] [FILE]"
      description "List files in a bundle"

      option :show_border, short: "-b", desc: "Show detected border pattern"

      argument :file, required: false, desc: "Bundle file (or stdin if omitted)"

      examples ["bundle.txt", "-b bundle.txt", "< bundle.txt"]

      # Forces ANSI color support even when stdout is not a TTY
      # (e.g. when piped from +codeball pack+).
      def env
        (super || {}).merge("TERM" => "1")
      end

      def run(io)
        input = io.read
        abort_if_empty(input)
        print_border(input) if options[:show_border]

        bundle = Bundle.parse(input, config: Config.default)
        print_warnings(bundle.parse_errors)

        rows = bundle.entries.map { |e| [e.path, "#{e.line_count} lines"] }
        print_table_color(rows, header: %w[File Lines], color: :green, index: 0)
      end

      private

      def abort_if_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end

      def print_border(input)
        border = Bundle.detect_border(input)
        puts "#{colors.bold("border")}: #{border.inspect}" if border
        puts
      end

      def print_warnings(errors)
        errors.each { |msg| stderr.puts colors.yellow("warning: #{msg}") }
      end
    end
  end
end
