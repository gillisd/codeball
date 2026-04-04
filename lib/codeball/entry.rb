require "pathname"
require "filemagic"

module Codeball
  # A single file entry within a bundle, with path and contents.
  #
  # Entry is the atomic unit of a bundle. It knows how to read itself from disk,
  # validate its path for safe extraction, and write itself to an output directory.
  #
  class Entry
    attr_reader :path, :contents

    # Reads a file from disk and wraps it in an Entry.
    # Returns `nil` if the file doesn't exist or isn't readable.
    def self.from_file(path)
      path = Pathname.new(path)
      return nil unless path.exist? && path.readable?

      new(path: path.to_s, contents: path.read)
    end

    def self.magic_client
      @magic_client ||= FileMagic.mime
    end

    def initialize(path:, contents:, magic_client: nil)
      raise ArgumentError, "Path must be present" if path.nil? || path.strip.empty?

      @path = path
      @contents = contents
      @magic_client = magic_client || self.class.magic_client
    end

    def empty? = contents.empty?
    def byte_size = contents.bytesize

    def line_count
      return 0 if contents.empty?

      contents.count("\n") + (contents.end_with?("\n") ? 0 : 1)
    end

    def text?
      contents.empty? || !mime_type.include?("charset=binary")
    end

    def serialize(border)
      header = "#{border}\nBEGIN #{path.inspect}\n#{border}\n"
      footer = "#{border}\nEND #{path.inspect}\n#{border}\n"
      "#{header}#{contents}#{footer}"
    end

    def mime_type
      @mime_type ||= @magic_client.buffer(@contents)
    end

    def safe_for?(output_dir)
      dangerous_patterns = [
        /\A\.\./,     # starts with ..
        %r{/\.\.},    # contains /..
        %r{\A/}, # absolute path
        /\A~/, # home directory expansion
      ]

      return false if dangerous_patterns.any? { |pattern| path.match?(pattern) }

      resolved_path(output_dir).to_s.start_with?(output_dir.to_s)
    end

    def resolved_path(output_dir)
      (output_dir / path).expand_path
    end

    # Writes this entry to disk. Returns an ExtractionResult.
    def write_to(output_dir, dry_run: false)
      return ExtractionResult.new(path: path, status: :unsafe) unless safe_for?(output_dir)

      resolved = resolved_path(output_dir)
      dry_run ? dry_run_result(resolved) : persist(resolved)
    rescue SystemCallError => e
      ExtractionResult.new(path: path, error: e.message, status: :failed)
    end

    private

    attr_reader :magic_client

    def dry_run_result(resolved)
      ExtractionResult.new(path: resolved, line_count: line_count, status: :dry_run)
    end

    def persist(resolved)
      resolved.parent.mkpath
      resolved.write(contents)
      ExtractionResult.new(path: resolved, line_count: line_count, status: :written)
    end
  end
end
