require "command_kit/commands/command"
require "command_kit/printing/tables"
require "command_kit/colors"
require "command_kit/open"

module CommandKit
  ##
  # Extends +CommandKit::Printing+ with color-aware table printing.
  #
  # Computes column widths from raw text, then applies ANSI color
  # after padding so escape sequences don't break alignment.
  module Printing
    def print_table_color(rows, header: nil, color: :green, index: 0, **)
      all_rows = header ? [header] + rows : rows
      widths = column_widths(all_rows)
      print_header(header, widths) if header
      rows.each do |row|
        line = format_row(row, widths, color, index)
        puts line.join("  ")
      end
    end

    private

    def print_header(header, widths)
      line = header.each_with_index.map do |cell, i|
        colors.bold(cell.to_s.ljust(widths[i]))
      end
      puts line.join("  ")
    end

    def format_row(row, widths, color, index)
      row.each_with_index.map do |cell, i|
        padded = cell.to_s.ljust(widths[i])
        i == index ? colors.public_send(color, padded) : padded
      end
    end

    def column_widths(rows)
      rows.each_with_object(Hash.new(0)) do |row, widths|
        row.each_with_index do |cell, i|
          len = cell.to_s.length
          widths[i] = len if len > widths[i]
        end
      end
    end
  end
end

module CommandKit
  ##
  # Opens readable arguments as IO streams, defaulting to stdin.
  # Uses <tt>CommandKit::Open#open</tt> to handle filenames and +"-"+ for stdin.
  module CombinedIO
    include CommandKit::Open

    def self.included(base)
      base.prepend Prepended
    end

    ##
    # Prepends +run+ to open file arguments (or stdin) as IO streams.
    module Prepended
      def run(*args)
        args << "-" if args.empty?

        ios = args.map { |readable| open(readable) }

        begin
          super(*ios)
        ensure
          ios.each(&:close)
        end
      end
    end
  end
end

module Codeball
  module Commands
    ##
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

      ##
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
