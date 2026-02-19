module Codeball
  # Represents the outcome of extracting a single entry from a bundle.
  #
  # ## Example
  #
  # ```ruby
  # result = entry.write_to(output_dir)
  # if result.success?
  #   puts "Wrote #{result.path}"
  # else
  #   puts "Failed: #{result.error}"
  # end
  # ```
  #
  ExtractionResult = Struct.new(:path, :size, :status, :error, keyword_init: true) do
    # Whether the extraction completed successfully.
    # Both actual writes and dry-run simulations count as success.
    def success? = status.in?(%i[written dry_run])
  end
end

# Add in? to Symbol for cleaner predicate
class Symbol
  def in?(collection) = collection.include?(self)
end
