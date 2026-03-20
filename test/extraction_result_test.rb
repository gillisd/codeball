require_relative "test_helper"

class ExtractionResultTest < Minitest::Test
  def test_success_for_written
    result = Codeball::ExtractionResult.new(path: "x", status: :written)

    assert_predicate result, :success?
  end

  def test_success_for_dry_run
    result = Codeball::ExtractionResult.new(path: "x", status: :dry_run)

    assert_predicate result, :success?
  end

  def test_not_success_for_unsafe
    result = Codeball::ExtractionResult.new(path: "x", status: :unsafe)

    refute_predicate result, :success?
  end

  def test_not_success_for_failed
    result = Codeball::ExtractionResult.new(path: "x", status: :failed, error: "oops")

    refute_predicate result, :success?
  end
end
