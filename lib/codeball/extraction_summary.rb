module Codeball
  # Aggregates results from extracting multiple entries.
  # Pure data class - no output methods.
  #
  class ExtractionSummary
    attr_reader :results, :malformed

    def initialize(results, malformed: 0)
      @results = results
      @malformed = malformed
    end

    def extracted = results.count(&:success?)
    def skipped = results.count { !_1.success? }
  end
end
