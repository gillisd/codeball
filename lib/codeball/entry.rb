require "pathname"
require "filemagic"

module Codeball
  # An in-memory buffer representing a single file within a codeball.
  #
  # Entry holds a file path and contents. It knows how to serialize
  # itself into bordered codeball format and detect whether its
  # contents are text or binary.
  #
  class Entry
    attr_reader :path, :contents

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

    def serialize
      border = Border::SEPARATOR
      header = "#{border}\nBEGIN #{path.inspect}\n#{border}\n"
      footer = "#{border}\nEND #{path.inspect}\n#{border}\n"
      "#{header}#{contents}#{footer}"
    end

    def mime_type
      @mime_type ||= @magic_client.buffer(@contents)
    end

    private

    attr_reader :magic_client
  end
end
