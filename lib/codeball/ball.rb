module Codeball
  # A codeball -- the aggregate root.
  #
  # Ball is an ordered collection of file entries that can be serialized
  # to bordered text for clipboard transfer. Pure data -- does not read
  # from or write to the filesystem.
  #
  class Ball
    def self.parse(text, cursor: nil)
      raise MalformedBallError, "empty input, nothing to extract" if text.nil? || text.strip.empty?

      cursor ||= Cursor.new(text)
      entries, errors = extract_entries(cursor)
      validate_entries(entries, errors)

      new(entries, parse_warnings: errors)
    end

    def self.extract_entries(cursor)
      entries = []
      errors = []
      until cursor.finished?
        next(cursor.advance) unless cursor.at_begin_marker?

        entry, error = read_entry(cursor)
        entries << entry if entry
        errors << error if error
      end
      [entries, errors]
    end
    private_class_method :extract_entries

    def self.read_entry(cursor)
      path = cursor.marker_path
      content = cursor.read_content_until_end(path)

      if content
        [Entry.new(path: path, contents: content), nil]
      else
        [nil, "truncated entry for #{path.inspect} - missing END marker"]
      end
    end
    private_class_method :read_entry

    def self.validate_entries(entries, errors)
      if entries.empty? && errors.any?
        raise MalformedBallError, "no valid entries found (#{errors.length} malformed)"
      elsif entries.empty?
        raise MalformedBallError, "no content found - is this a codeball bundle?"
      end
    end
    private_class_method :validate_entries

    def initialize(entries, parse_warnings: [])
      @entries = entries.freeze
      @parse_warnings = parse_warnings.freeze
    end

    def each_entry(&) = entries.each(&)
    def each_text_entry(&) = entries.select(&:text?).each(&)
    def each_non_text_entry(&) = entries.reject(&:text?).each(&)
    def each_parse_warning(&) = parse_warnings.each(&)

    def all_text? = entries.all?(&:text?)
    def parse_warning_count = parse_warnings.length

    def serialize
      entries.select(&:text?).map(&:serialize).join
    end

    private

    attr_reader :entries, :parse_warnings
  end
end
