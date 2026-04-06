module Codeball
  # A codeball -- the aggregate root.
  #
  # Ball starts empty and grows as entries are added, like a snowball.
  # It does not touch the filesystem. Parse is a thin factory that
  # wires Cursor -> Stream -> Ball.
  #
  class Ball
    def self.parse(text)
      raise MalformedBallError, "empty input, nothing to extract" if text.nil? || text.strip.empty?

      ball = new
      stream = Stream.new(cursor: Cursor.new(text))
      stream.each_entry { |entry| ball.add_entry(entry) }
      ball.validate!
      ball
    end

    def initialize
      @entries = []
      @warnings = []
    end

    def add_entry(entry)
      @entries << entry
      @warnings << entry.error if entry.errors?
      @warnings << "truncated entry for #{entry.path.inspect} - missing END marker" if entry.truncated?
    end

    def validate!
      valid = entries.select(&:valid?)
      if valid.empty? && warnings.any?
        raise MalformedBallError, "no valid entries found (#{warnings.length} malformed)"
      elsif valid.empty?
        raise MalformedBallError, "no content found - is this a codeball?"
      end
    end

    def each_entry(&) = entries.select(&:valid?).each(&)
    def each_text_entry(&) = entries.select(&:valid?).select(&:text?).each(&)
    def each_non_text_entry(&) = entries.select(&:valid?).reject(&:text?).each(&)
    def each_warning(&) = warnings.each(&)
    def all_text? = entries.select(&:valid?).all?(&:text?)
    def warning_count = warnings.length

    def serialize
      entries.select(&:valid?).select(&:text?).map(&:serialize).join
    end

    private

    attr_reader :entries, :warnings
  end
end
