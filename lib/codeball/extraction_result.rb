module Codeball
  # Represents the outcome of extracting a single entry from a codeball.
  #
  # ## Example
  #
  # ```ruby
  #   puts "Wrote #{result.path}"
  #   puts "Failed: #{result.error}"
  # ```
  #
  ExtractionResult = Struct.new(:path, :line_count, :status, :error) do
    # Whether the extraction completed successfully.
    # Both actual writes and dry-run simulations count as success.
    def success? = %i[written dry_run].include?(status)
  end
end
