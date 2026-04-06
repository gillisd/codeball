module Codeball
  # A lexer for codeball-formatted text.
  #
  # Cursor walks text line by line and classifies each meaningful
  # element as a typed token: Header, Body, or Footer. Borders are
  # delimiters consumed internally -- they are never yielded.
  #
  # Cursor does not correlate tokens or enforce sequencing.
  # Stream handles assembly; Entry enforces invariants.
  #
  class Cursor
    BEGIN_PATTERN = /\ABEGIN\s+["']?(.+?)["']?\s*\z/
    END_PATTERN = /\AEND\s+["']?(.+?)["']?\s*\z/

    # Sentinel returned when all tokens have been consumed.
    module EOF; end

    def initialize(text)
      @lines = text.lines
      @position = 0
      @pending_footer = nil
      @body_lines = nil
    end

    def next_item
      return emit_footer if @pending_footer

      skip_borders
      return EOF if finished?

      if @body_lines
        read_body
      else
        read_header_or_eof
      end
    end

    private

    attr_reader :lines, :position

    def finished? = position >= lines.length
    def current_line = lines[position]&.strip
    def raw_line = lines[position]

    def advance
      @position += 1
    end

    def peek_line
      lines[position + 1]&.strip
    end

    def skip_borders
      advance while !finished? && Border.recognize?(current_line)
    end

    def read_header_or_eof
      match = current_line&.match(BEGIN_PATTERN)
      return EOF unless match

      advance
      skip_borders
      @body_lines = []
      Header.new(match[1])
    end

    def read_body
      collect_body_lines
      body = Body.new(Border.strip_suffix(@body_lines.join))
      @body_lines = nil
      body
    end

    def collect_body_lines
      until finished?
        return found_end(current_line.match(END_PATTERN)) if end_marker?
        return found_end_after_border if border_before_end?

        @body_lines << raw_line
        advance
      end
    end

    def end_marker?
      current_line&.match?(END_PATTERN)
    end

    def border_before_end?
      Border.recognize?(current_line) &&
        peek_line&.match?(END_PATTERN)
    end

    def found_end(match)
      @pending_footer = match[1]
      advance
    end

    def found_end_after_border
      advance
      end_match = current_line.match(END_PATTERN)
      @pending_footer = end_match[1]
      advance
    end

    def emit_footer
      path = @pending_footer
      @pending_footer = nil
      Footer.new(path)
    end
  end
end
