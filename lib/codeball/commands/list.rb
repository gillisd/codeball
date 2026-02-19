require "command_kit/commands/command"
require "command_kit/colors"

module Codeball
  module Commands
    # List files contained in a codeball bundle.
    #
    class List < CommandKit::Commands::Command
      include CommandKit::Colors

      usage "[options] [FILE]"
      description "List files in a bundle"

      option :show_border, short: "-b",
                           desc: "Show detected border pattern"

      argument :file, required: false,
                      desc: "Bundle file (or stdin if omitted)"

      examples [
        "bundle.txt",
        "-b bundle.txt",
        "< bundle.txt"
      ]

      def run(file = nil)
        ARGV.replace(file ? [file] : [])
        input = ARGF.read

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

        total_lines = 0
        bundle.entries.each do |entry|
          lines = entry.line_count
          total_lines += lines
          puts "#{lines.to_s.rjust(6)} lines  #{entry.path}"
        end

        puts "---"
        puts "#{colors.bold(bundle.entries.length.to_s)} files, #{colors.bold(total_lines.to_s)} lines"

        if bundle.parse_errors.any?
          puts colors.yellow("#{bundle.parse_errors.length} malformed")
        end
      end
    end
  end
end
