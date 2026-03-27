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
  # bundle = Bundle.from_files(["lib/foo.rb", "lib/bar.rb"])
  # bundle.serialize  # writes to stdout
  # ```
  #
  # Unpacking a bundle from text:
  #
  # ```ruby
  # bundle = Bundle.parse(clipboard_contents)
  # bundle.extract  # writes files to disk
  # ```
  #
  class Bundle
    attr_reader :entries, :config, :parse_errors

    def text_entries
      entries.select(&:text?)
    end

    def non_text_entries
      entries.reject(&:text?)
    end

    # Creates a bundle by reading files from disk.
    def self.from_files(paths, config: Config.default)
      entries = paths.filter_map { |path| Entry.from_file(path) }
      new(entries, config: config)
    end

    # Parses a bundle from serialized text.
    # Resilient to partial or truncated input - extracts what it can and warns about the rest.
    # Parse errors are stored in `parse_errors` for later reporting.
    def self.parse(text, config: Config.default)
      raise MalformedBundleError, "empty input, nothing to extract" if text.nil? || text.strip.empty?

      entries = []
      errors = []

      # Find all BEGIN markers that follow a border line
      lines = text.lines
      i = 0

      while i < lines.length
        line = lines[i].strip

        # Only recognize BEGIN if preceded by a border line
        if line.start_with?("BEGIN ") && i > 0 && looks_like_border?(lines[i - 1].strip)
          path = extract_path_from_line(line)
          if path
            content_start = find_content_start(lines, i + 1)
            if content_start
              content_end, footer_line = find_content_end(lines, content_start, path)
              if content_end
                content = extract_content(lines, content_start, content_end)
                entries << Entry.new(path: path, contents: content)
                i = footer_line + 1
                next
              else
                errors << "truncated entry for #{path.inspect} - missing END marker"
              end
            else
              errors << "malformed entry for #{path.inspect} - no content border found"
            end
          end
        end

        i += 1
      end

      if entries.empty? && errors.any?
        raise MalformedBundleError, "no valid entries found (#{errors.length} malformed)"
      elsif entries.empty?
        raise MalformedBundleError, "no content found - is this a codeball bundle?"
      end

      new(entries, config: config, parse_errors: errors)
    end

    # Extracts path from a BEGIN line like: BEGIN "path/to/file.rb"
    def self.extract_path_from_line(line)
      match = line.match(/\ABEGIN\s+["']?(.+?)["']?\s*\z/)
      match[1] if match
    end

    # Finds the line index where content starts (after the border following BEGIN)
    def self.find_content_start(lines, from)
      i = from
      # Skip any border line(s) to find content
      while i < lines.length
        line = lines[i].strip
        break unless looks_like_border?(line)
        i += 1
      end
      # If we found non-border content, the content starts here
      # But we need to back up if we hit the content - the border was the line before
      # Actually, content starts at i (the first non-border line after BEGIN's border)
      i < lines.length ? i : nil
    end

    # Finds where content ends by looking for END marker with matching path
    # Finds where content ends by looking for END marker with matching path
    def self.find_content_end(lines, content_start, path)
      i = content_start
      while i < lines.length
        line = lines[i]
        stripped = line.strip

        # Check if this line contains END marker for this exact path
        if stripped.include?("END \"#{path}\"") || stripped.include?("END '#{path}'") || stripped == "END #{path}"
          return [i - 1, i]
        end

        # Check if line is a border followed by END on next line
        if looks_like_border?(stripped) && i + 1 < lines.length
          next_stripped = lines[i + 1].strip
          if next_stripped.start_with?("END ")
            end_path = extract_path_from_line(next_stripped.sub(/\AEND/, "BEGIN"))
            return [i - 1, i + 1] if end_path == path
          end
        end

        i += 1
      end
      nil
    end

    # Extracts content from lines between start and end indices (inclusive)
    # Handles borders appearing at end of content lines
    def self.extract_content(lines, start_idx, end_idx)
      return "" if end_idx < start_idx

      # Skip leading border lines
      while start_idx <= end_idx && looks_like_border?(lines[start_idx].strip)
        start_idx += 1
      end

      return "" if start_idx > end_idx

      content_lines = lines[start_idx..end_idx]
      result = content_lines.join

      # Check if last line has border suffix (content and border on same line)
      # Pattern: content followed by repeated punctuation (border)
      border_suffix = result.match(/[-#=~*_|+][-#=~*_|+\s]{8,}\s*\z/)

      if border_suffix
        # Content didn't end with newline - border was on same line
        # Strip the border and the trailing newline (which belongs to the line, not content)
        result = result.sub(/[-#=~*_|+][-#=~*_|+\s]{8,}\s*\z/, "").chomp
      else
        # Content ended with newline, border was on its own line
        # Remove only the final newline that's an artifact of line joining
        # But preserve trailing newlines that are part of content
        # Actually, the join preserves everything correctly, we just need to not add extra
      end

      result
    end

    # Heuristic: does this line look like a border?
    # Borders are lines consisting mainly of repeated punctuation like --- or ###
    # possibly separated by whitespace (tabs converted to spaces, etc.)
    def self.looks_like_border?(line)
      return false if line.empty?
      return false if line.start_with?("BEGIN ", "END ")

      # Remove all whitespace and check what's left
      stripped = line.gsub(/\s+/, "")
      return false if stripped.empty?
      return false if stripped.length < 6  # Too short to be a border

      # A border is made of repeated punctuation characters
      # Check if it's all the same punctuation char, or a repeating pattern
      chars = stripped.chars.uniq

      # All same character (e.g., "----------")
      return true if chars.length == 1 && !chars.first.match?(/[a-zA-Z0-9]/)

      # Repeating pattern like "---" repeated = all dashes
      # Or "###" repeated = all hashes
      # Check if it's only punctuation/dashes
      return true if stripped.match?(/\A[-#=~*_|+]+\z/) && stripped.length >= 9

      false
    end

    # Returns the border pattern detected in the bundle, or nil if not determinable.
    def self.detect_border(text)
      return nil if text.nil? || text.empty?
      first_line = text.lines.first&.chomp
      first_line if looks_like_border?(first_line.to_s)
    end

    def initialize(entries, config: Config.default, parse_errors: [])
      @entries = entries
      @config = config
      @parse_errors = parse_errors
    end

    # Serializes the bundle to stdout for piping to clipboard.
    def serialize
      puts text_entries.map { it.serialize(config.full_border) }
    end

    # Extracts all entries to disk.
    # Returns an ExtractionSummary with per-file results.
    def extract
      output_dir = Pathname.new(config.output_dir).expand_path
      results = entries.map { |entry| entry.write_to(output_dir, dry_run: config.dry_run) }
      ExtractionSummary.new(results, malformed: parse_errors.length)
    end

    private

  end
end
