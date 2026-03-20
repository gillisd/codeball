require_relative "test_helper"

class ExtractionSummaryTest < Minitest::Test
  def test_counts_successful_extractions
    results = [
      Codeball::ExtractionResult.new(path: "a", status: :written),
      Codeball::ExtractionResult.new(path: "b", status: :written),
      Codeball::ExtractionResult.new(path: "c", status: :unsafe)
    ]

    summary = Codeball::ExtractionSummary.new(results)

    assert_equal 2, summary.extracted
    assert_equal 1, summary.skipped
  end

  def test_dry_run_counts_as_extracted
    results = [
      Codeball::ExtractionResult.new(path: "a", status: :dry_run),
      Codeball::ExtractionResult.new(path: "b", status: :dry_run)
    ]

    summary = Codeball::ExtractionSummary.new(results)

    assert_equal 2, summary.extracted
    assert_equal 0, summary.skipped
  end
end
