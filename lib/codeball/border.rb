module Codeball
  # Domain knowledge about the visual delimiter between sections in a codeball.
  #
  # Borders are repeated punctuation patterns that separate entries in
  # serialized codeball text. The pattern is fixed, not configurable.
  #
  # During serialization, SEPARATOR is used as-is.
  # During parsing, recognition is heuristic to tolerate mangling
  # by browsers, editors, and clipboard transfer.
  #
  module Border
    PATTERN = "---\t"
    WIDTH = 10
    SEPARATOR = (PATTERN * WIDTH).freeze
    SUFFIX = /[-#=~*_|+][-#=~*_|+\s]{8,}\s*\z/
    MIN_LENGTH = 6
    MIN_PUNCTUATION_LENGTH = 9

    module_function

    def recognize?(line)
      return false if line.empty?
      return false if line.start_with?("BEGIN ", "END ")

      stripped = line.gsub(/\s+/, "")
      return false if stripped.empty?
      return false if stripped.length < MIN_LENGTH

      single_char?(stripped) || punctuation_run?(stripped)
    end

    def strip_suffix(text)
      text.match?(SUFFIX) ? text.sub(SUFFIX, "").chomp : text
    end

    def single_char?(stripped)
      chars = stripped.chars.uniq
      chars.length == 1 && !chars.first.match?(/[a-zA-Z0-9]/)
    end

    def punctuation_run?(stripped)
      stripped.match?(/\A[-#=~*_|+]+\z/) && stripped.length >= MIN_PUNCTUATION_LENGTH
    end

    private_class_method :single_char?, :punctuation_run?
  end
end
