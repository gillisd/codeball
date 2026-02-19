require "command_kit/commands/command"
require "command_kit/printing/tables"
require "command_kit/colors"
require "command_kit/open"

module Foobar
  refine CommandKit::Printing::Tables::TableFormatter do
    import_methods CommandKit::Colors

    def env
      (super || {}).merge("TERM" => "1")
    end

    private

    alias_method :o_format_row, :format_row

    def format_row(row, **optargs)
      row.cells.select.with_index do |val, i|
        i == 1
      end.each do |it|
        it.lines.each.with_index do |line, index|
          it.lines[index] = colors.green(line)
        end
      end
      o_format_row(row, **optargs) do |*args, **kwargs|
        yield(*args, **kwargs)
      end
    end
  end
end

module CommandKit::Printing
  def print_table_color(*, color: :green, index: 0, **)
    f = Fiber.new do
      print_table(*, **)
    end
    row = f.resume
    format! row, color: color, index: index
    while row = f.resume(row)
      format! row, color: color, index: index
    end
  end

  def print_foo(*)
    f = Fiber.new do
      print_table(*)
    end
    row = f.resume
    while row = f.resume(row)

    end
  end

  def format!(row, color:, index:)
    row.cells.select.with_index do |val, i|
      i == index
    end.each do |it|
      it.lines.each.with_index do |line, index|
        it.lines[index] = colors.public_send(color, line).then do |new|
          new + ("  " * ((new.length * 2) - line.length))
        end.to_s
      end
    end
  end

  class Tables::TableFormatter
    include CommandKit::Colors

    def env
      (super || {}).merge("TERM" => "1")
    end

    private

    alias o_format_row format_row

    def format_row(row, **)
      row = Fiber.yield row
      o_format_row(row, **) do |*args, **kwargs|
        yield(*args, **)
      end
    end
  end
end

module CommandKit::Combinedio
  include CommandKit::Open

  def self.included(base)
    base.prepend Prepended
  end

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

module Codeball
  module Commands
    # List files contained in a codeball bundle.
    #
    class List < CommandKit::Commands::Command
      include CommandKit::Combinedio
      include CommandKit::Colors
      include CommandKit::Printing::Tables

      using Foobar

      usage "[options] [FILE]"
      description "List files in a bundle"

      option :show_border, short: "-b", desc: "Show detected border pattern"

      argument :file, required: false, desc: "Bundle file (or stdin if omitted)"

      examples ["bundle.txt", "-b bundle.txt", "< bundle.txt"]

      def run(io)
        input = io.read
        if input.nil? || input.strip.empty?
          print_error "no input"
          exit 1
        end

        if options[:show_border]
          border = Bundle.detect_border(input)
          puts "#{colors.bold('border')}: #{border.inspect}" if border
          puts
        end

        bundle = Bundle.parse(input, config: Config.default)

        bundle.parse_errors.each do |msg|
          stderr.puts colors.yellow("warning: #{msg}")
        end

        print_table_color bundle.entries.map { |entry|
          [entry.line_count, entry.path].reverse
        }, color: :white, index: 0
        print_foo bundle.entries.map { |entry| [entry.line_count, entry.path.length].reverse }
        return

        total_lines = 0
        bundle.entries.each do |entry|
          lines = entry.line_count
          total_lines += lines
          puts "#{lines.to_s.rjust(6)} lines  #{entry.path}"
        end

        puts "---"
        # puts "#{colors.bold(bundle.entries.length.to_s)} files, #{colors.bold(total_lines.to_s)} lines"

        return unless bundle.parse_errors.any?

        puts colors.yellow("#{bundle.parse_errors.length} malformed")
      end
    end
  end
end
