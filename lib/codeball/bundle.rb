require "pathname"

module Codeball
  # A collection of file entries that can be serialized to text (packed)
  # or extracted to disk (unpacked).
  #
  # Bundle is the core domain object. It can be created from files on disk,
  # parsed from serialized text, serialized to stdout, or extracted to disk.
  #
  # ## Examples
  #
  # Packing files into a bundle:
  #
  # ```ruby
  # bundle.serialize  # writes to stdout
  # ```
  #
  # Unpacking a bundle from text:
  #
  # ```ruby
  # bundle.extract  # writes files to disk
  # ```
  #
  class Bundle
    BEGIN_MARKER_PATTERN = /\ABEGIN\s+["']?(.+?)["']?\s*\z/
    BORDER_SUFFIX_PATTERN = /[-#=~*_|+][-#=~*_|+\s]{8,}\s*\z/

    attr_reader :entries, :config, :parse_errors

    # Creates a bundle by reading files from disk.
    def self.from_files(paths, config: Config.default)
      entries = paths.filter_map { |path| Entry.from_file(path) }
      new(entries, config: config)
    end

    # Parses a bundle from serialized text.
    # Resilient to partial or truncated input - extracts what it can and warns about the rest.
    # Parse errors are stored in `parse_errors` for later reporting.
    def self.parse(text, config: Config.default)
      validate_input(text)

      entries, errors = collect_entries(text.lines)
      build_bundle_from_results(entries, errors, config)
    end

    def self.extract_path_from_line(line)
      match = line.match(BEGIN_MARKER_PATTERN)
      match[1] if match
    end

    def self.find_content_start(lines, from)
      idx = from
      while idx < lines.length
        line = lines[idx].strip
        break unless looks_like_border?(line)

        idx += 1
      end
      idx < lines.length ? idx : nil
    end

    def self.find_content_end(lines, content_start, path)
      idx = content_start
      while idx < lines.length
        return [idx - 1, idx] if inline_end_marker?(lines[idx].strip, path)

        border_end = end_marker_after_border(lines, idx, path)
        return border_end if border_end

        idx += 1
      end
      nil
    end

    def self.extract_content(lines, start_idx, end_idx)
      return "" if end_idx < start_idx

      start_idx += 1 while start_idx <= end_idx && looks_like_border?(lines[start_idx].strip)
      return "" if start_idx > end_idx

      strip_border_suffix(lines[start_idx..end_idx].join)
    end

    # Heuristic: does this line look like a border?
    # Borders are lines consisting mainly of repeated punctuation like --- or ###
    # possibly separated by whitespace (tabs converted to spaces, etc.)
    def self.looks_like_border?(line)
      return false if line.empty?
      return false if line.start_with?("BEGIN ", "END ")

      stripped = line.gsub(/\s+/, "")
      return false if stripped.empty?
      return false if stripped.length < 6

      single_char_border?(stripped) || punctuation_border?(stripped)
    end

    # Returns the border pattern detected in the bundle, or nil if not determinable.
    def self.detect_border(text)
      return nil if text.nil? || text.empty?

      first_line = text.lines.first&.chomp
      first_line if looks_like_border?(first_line.to_s)
    end

    def self.validate_input(text)
      raise MalformedBundleError, "empty input, nothing to extract" if text.nil? || text.strip.empty?
    end
    private_class_method :validate_input

    def self.collect_entries(lines)
      entries = []
      errors = []
      idx = 0

      while idx < lines.length
        entry, error, advance = try_parse_entry(lines, idx)
        entries << entry if entry
        errors << error if error
        idx += advance || 1
      end

      [entries, errors]
    end
    private_class_method :collect_entries

    def self.try_parse_entry(lines, idx)
      line = lines[idx].strip
      return [nil, nil, nil] unless begin_marker_at?(lines, idx, line)

      path = extract_path_from_line(line)
      return [nil, nil, nil] unless path

      parse_entry_content(lines, idx, path)
    end
    private_class_method :try_parse_entry

    def self.begin_marker_at?(lines, idx, line)
      line.start_with?("BEGIN ") && idx.positive? && looks_like_border?(lines[idx - 1].strip)
    end
    private_class_method :begin_marker_at?

    def self.parse_entry_content(lines, idx, path)
      content_start = find_content_start(lines, idx + 1)
      return [nil, "malformed entry for #{path.inspect} - no content border found", nil] unless content_start

      content_end, footer_line = find_content_end(lines, content_start, path)
      return [nil, "truncated entry for #{path.inspect} - missing END marker", nil] unless content_end

      content = extract_content(lines, content_start, content_end)
      entry = Entry.new(path: path, contents: content)
      [entry, nil, footer_line - idx + 1]
    end
    private_class_method :parse_entry_content

    def self.build_bundle_from_results(entries, errors, config)
      if entries.empty? && errors.any?
        raise MalformedBundleError, "no valid entries found (#{errors.length} malformed)"
      elsif entries.empty?
        raise MalformedBundleError, "no content found - is this a codeball bundle?"
      end

      new(entries, config: config, parse_errors: errors)
    end
    private_class_method :build_bundle_from_results

    def self.inline_end_marker?(stripped, path)
      stripped.include?("END \"#{path}\"") ||
        stripped.include?("END '#{path}'") ||
        stripped == "END #{path}"
    end
    private_class_method :inline_end_marker?

    def self.end_marker_after_border(lines, idx, path)
      return nil unless looks_like_border?(lines[idx].strip) && idx + 1 < lines.length

      next_stripped = lines[idx + 1].strip
      return nil unless next_stripped.start_with?("END ")

      end_path = extract_path_from_line(next_stripped.sub(/\AEND/, "BEGIN"))
      [idx - 1, idx + 1] if end_path == path
    end
    private_class_method :end_marker_after_border

    def self.strip_border_suffix(result)
      if result.match?(BORDER_SUFFIX_PATTERN)
        result.sub(BORDER_SUFFIX_PATTERN, "").chomp
      else
        result
      end
    end
    private_class_method :strip_border_suffix

    def self.single_char_border?(stripped)
      chars = stripped.chars.uniq
      chars.length == 1 && !chars.first.match?(/[a-zA-Z0-9]/)
    end
    private_class_method :single_char_border?

    def self.punctuation_border?(stripped)
      stripped.match?(/\A[-#=~*_|+]+\z/) && stripped.length >= 9
    end
    private_class_method :punctuation_border?

    def initialize(entries, config: Config.default, parse_errors: [])
      @entries = entries
      @config = config
      @parse_errors = parse_errors
    end

    def text_entries = entries.select(&:text?)

    def non_text_entries = entries.reject(&:text?)

    # Serializes the bundle to stdout for piping to clipboard.
    def serialize
      puts(text_entries.map { it.serialize(config.full_border) })
    end

    # Extracts all entries to disk.
    # Returns an ExtractionSummary with per-file results.
    def extract
      output_dir = Pathname.new(config.output_dir).expand_path
      results = entries.map { |entry| entry.write_to(output_dir, dry_run: config.dry_run) }
      ExtractionSummary.new(results, malformed: parse_errors.length)
    end
  end
end
