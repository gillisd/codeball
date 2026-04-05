require "pathname"

module Codeball
  # A filesystem context that writes entries to an output directory.
  #
  # Destination decorates a directory path with the ability to receive
  # codeball entries. It owns path safety validation, parent directory
  # creation, and dry-run simulation.
  #
  # Tracks outcomes internally and provides a summary when asked.
  #
  class Destination
    DANGEROUS_PATTERNS = [
      /\A\.\./,
      %r{/\.\.},
      %r{\A/},
      /\A~/,
    ].freeze

    attr_reader :output_dir

    def initialize(output_dir = ".", dry_run: false)
      @output_dir = Pathname.new(output_dir).expand_path
      @dry_run = dry_run
      @results = []
    end

    def dry_run? = @dry_run

    def write(entry)
      outcome = write_entry(entry)
      @results << outcome
      yield outcome if block_given?
      outcome
    end

    def summary(malformed: 0)
      ExtractionSummary.new(@results, malformed: malformed)
    end

    private

    def write_entry(entry)
      return unsafe_result(entry) unless safe_path?(entry.path)

      resolved = resolve(entry.path)
      dry_run? ? dry_run_result(entry, resolved) : persist(entry, resolved)
    rescue SystemCallError => e
      ExtractionResult.new(path: entry.path, error: e.message, status: :failed)
    end

    def safe_path?(path)
      return false if DANGEROUS_PATTERNS.any? { |pattern| path.match?(pattern) }

      resolve(path).to_s.start_with?(output_dir.to_s)
    end

    def resolve(path)
      (output_dir / path).expand_path
    end

    def unsafe_result(entry)
      ExtractionResult.new(path: entry.path, status: :unsafe)
    end

    def dry_run_result(entry, resolved)
      ExtractionResult.new(path: resolved, line_count: entry.line_count, status: :dry_run)
    end

    def persist(entry, resolved)
      resolved.parent.mkpath
      resolved.write(entry.contents)
      ExtractionResult.new(path: resolved, line_count: entry.line_count, status: :written)
    end
  end
end
