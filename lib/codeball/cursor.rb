module Codeball
  # A position in codeball-formatted text.
  #
  # Cursor wraps a sequence of lines and an index, providing navigation
  # through the structural elements of a serialized codeball: borders,
  # BEGIN/END markers, and file content.
  #
  class Cursor
    MARKER_PATTERN = /\ABEGIN\s+["']?(.+?)["']?\s*\z/

    def initialize(text)
      @lines = text.lines
      @position = 0
    end

    def finished?
      position >= lines.length
    end

    def current_line
      lines[position]&.strip
    end

    def raw_line
      lines[position]
    end

    def advance
      @position += 1
    end

    def skip_borders
      advance while !finished? && Border.recognize?(current_line)
    end

    def at_begin_marker?
      return false unless current_line&.start_with?("BEGIN ")
      return false unless position.positive?

      Border.recognize?(previous_line)
    end

    def marker_path
      match = current_line&.match(MARKER_PATTERN)
      match[1] if match
    end

    def read_content_until_end(path)
      advance
      skip_borders
      collected = []

      until finished?
        return collected.join if at_end_marker?(path)

        collected << raw_line
        advance
      end

      nil
    end

    private

    attr_reader :lines, :position

    def previous_line
      lines[position - 1]&.strip
    end

    def peek_line
      lines[position + 1]&.strip
    end

    def at_end_marker?(path)
      stripped = current_line

      return true if end_marker_inline?(stripped, path)

      end_marker_after_border?(stripped, path)
    end

    def end_marker_inline?(stripped, path)
      stripped.include?("END \"#{path}\"") ||
        stripped.include?("END '#{path}'") ||
        stripped == "END #{path}"
    end

    def end_marker_after_border?(stripped, path)
      return false unless Border.recognize?(stripped)
      return false unless next_line_is_end_marker?(path)

      advance
      true
    end

    def next_line_is_end_marker?(path)
      peeked = peek_line
      return false unless peeked

      peeked.start_with?("END ") && extract_path(peeked) == path
    end

    def extract_path(line)
      rewritten = line.sub(/\AEND/, "BEGIN")
      match = rewritten.match(MARKER_PATTERN)
      match[1] if match
    end
  end
end
