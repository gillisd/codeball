require "command_kit/colors"

##
# Fluent matcher for asserting styled terminal output.
# Chain style methods that correspond to CommandKit::Colors::ANSI
# color names to build expected ANSI-colored segments.
class HaveOutputLine
  def initialize
    @segments = []
  end

  def method_missing(name, *args)
    return super unless CommandKit::Colors::ANSI.respond_to?(name)

    text = args.first or raise ArgumentError, "#{name}() requires a text argument"
    @segments << { style: name, text: text }
    self
  end

  def respond_to_missing?(name, include_private = false)
    CommandKit::Colors::ANSI.respond_to?(name) || super
  end

  def matches?(actual)
    @actual = actual
    @actual.to_s.lines.any? { |line| line_matches?(line) }
  end

  def does_not_match?(actual)
    @actual = actual
    @actual.to_s.lines.none? { |line| line_matches?(line) }
  end

  def failure_message
    "expected output to contain a line matching:\n  " \
      "#{expected_readable}\ngot:\n  " \
      "#{@actual.to_s.lines.map(&:chomp).join("\n  ")}"
  end

  def failure_message_when_negated
    "expected output not to contain a line matching:\n  " \
      "#{expected_readable}\n" \
      "but it was found"
  end

  def description
    "have output line #{expected_readable}"
  end

  private

  def line_matches?(line)
    pattern = @segments.map { |seg|
      Regexp.escape(CommandKit::Colors::ANSI.public_send(seg[:style], seg[:text]))
    }.join(".*?")
    Regexp.new(pattern).match?(line)
  end

  def expected_readable
    @segments.map { |seg| "[#{seg[:style]}]#{seg[:text]}[/]" }.join
  end
end

RSpec.configure do |config|
  config.include(Module.new do
    def have_output_line
      HaveOutputLine.new
    end
  end)
end
