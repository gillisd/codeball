require "pathname"
require "filemagic"

module Codeball
  # A single file within a codeball.
  #
  # Entry is a state machine with write-once setters for header, body,
  # and footer. It enforces the Header -> Body -> Footer sequence by
  # rejecting duplicate assignments and detecting mismatched footers.
  #
  # Two construction paths, same invariants:
  #   1. Token-by-token via Stream (parsing)
  #   2. All-at-once via Entry.from_file (packing)
  #
  class Entry
    attr_reader :header, :body, :footer, :error

    def self.from_file(path)
      pathname = Pathname.new(path)
      return nil unless pathname.exist? && pathname.readable?

      entry = new
      name = pathname.to_s
      entry.header = Header.new(name)
      entry.body = Body.new(pathname.read)
      entry.footer = Footer.new(name)
      entry
    end

    def self.magic_client
      @magic_client ||= FileMagic.mime
    end

    def initialize
      @header = nil
      @body = nil
      @footer = nil
      @error = nil
      @magic_client = self.class.magic_client
    end

    def header=(header)
      if @header
        @error = "duplicate header: already have #{@header}, received #{header}"
        return
      end
      @header = header
    end

    def body=(body)
      if @body
        @error = "duplicate body for #{path}"
        return
      end
      @body = body
    end

    def footer=(footer)
      if @footer
        @error = "duplicate footer for #{path}"
        return
      end
      @footer = footer
      @error = "footer #{footer} does not match header #{header}" unless footer_matches_header?
    end

    def valid? = !!(header && body && footer && !errors? && footer_matches_header?)
    def incomplete? = !valid? && !errors?
    def errors? = !error.nil?
    def truncated? = !!(header && (body.nil? || footer.nil?) && !errors?)

    def path = header&.to_s
    def contents = body&.to_s

    def empty? = contents&.empty? || contents.nil?
    def byte_size = contents&.bytesize || 0

    def line_count
      return 0 if contents.nil? || contents.empty?

      contents.count("\n") + (contents.end_with?("\n") ? 0 : 1)
    end

    def text?
      contents.nil? || contents.empty? || !mime_type.include?("charset=binary")
    end

    def serialize
      border = Border::SEPARATOR
      "#{border}\nBEGIN #{path.inspect}\n#{border}\n#{contents}#{border}\nEND #{path.inspect}\n#{border}\n"
    end

    def mime_type
      @mime_type ||= @magic_client.buffer(contents)
    end

    private

    attr_reader :magic_client

    def footer_matches_header?
      return true unless header && footer

      header.to_s == footer.to_s
    end
  end
end
