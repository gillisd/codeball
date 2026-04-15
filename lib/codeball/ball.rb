module Codeball
  # A codeball -- the aggregate root.
  #
  # Ball starts empty and grows as entries are added, like a snowball.
  # It does not touch the filesystem. Parse is a thin factory that
  # wires Cursor -> Stream -> Ball.
  #
  class Ball
    attr_reader :entries, :warnings

    def self.parse(text)
      raise MalformedBallError, "empty input, nothing to extract" if text.nil? || text.strip.empty?

      ball = new
      stream = Stream.new(cursor: Cursor.new(text))
      stream.each_entry { |entry| ball.add_entry(entry) }
      ball.validate!
      ball
    end

    def self.load_file(path)
      pathname = Pathname(path)
      raise "No file found" unless pathname.file?
      parse(pathname.read)
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

    def remove_entry(identifier)
      to_remove = (
        case identifier
        in Entry then identifier
        in String then each_entry.find { it.header == identifier }
        else raise ArgumentError, "#{identifier} is not a valid Entry or identifier"
        end
      )
      raise ArgumentError, "#{identifier} did not match an existing Entry in this Ball" unless to_remove
      @entries.delete(to_remove)
    end

    def validate!
      valid = entries.select(&:valid?)
      if valid.empty? && warnings.any?
        raise MalformedBallError, "no valid entries found (#{warnings.length} malformed)"
      elsif valid.empty?
        raise MalformedBallError, "no content found - is this a codeball?"
      end
    end

    def files
      each_entry.map(&:header)
    end

    def entry_count
      each_entry.count
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
  end
end
