require_relative "test_helper"

class ResilientParsingTest < Minitest::Test
  def setup
    @config = Codeball::Config.default
  end

  def test_parses_valid_entries_despite_truncated_final_entry
    # Two complete entries, one truncated
    input = <<~BUNDLE
      ##############################
      BEGIN "good1.txt"
      ##############################
      content one
      ##############################
      END "good1.txt"
      ##############################

      ##############################
      BEGIN "good2.txt"
      ##############################
      content two
      ##############################
      END "good2.txt"
      ##############################

      ##############################
      BEGIN "truncated.txt"
      ##############################
      this entry is truncated and has no END marker
    BUNDLE

    capture_io do
      bundle = Codeball::Bundle.parse(input, config: @config)

      assert_equal 2, bundle.entries.length
      assert_equal "good1.txt", bundle.entries[0].path
      assert_equal "good2.txt", bundle.entries[1].path
      assert_equal 1, bundle.parse_errors.length
      assert_includes bundle.parse_errors.first, "truncated"
    end
  end

  def test_parses_with_tabs_converted_to_spaces
    # Browsers often convert tabs to spaces.
    # When content has no trailing newline, border appears on same line.
    # Test that parsing works when tabs become spaces.
    border = "---     " * 10
    input = [
      border,
      'BEGIN "test.txt"',
      border,
      "hello world" + border,
      'END "test.txt"',
      border
    ].join("\n") + "\n"

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 1, bundle.entries.length
    assert_equal "test.txt", bundle.entries.first.path
    assert_equal "hello world", bundle.entries.first.contents
  end

  def test_parses_single_truncated_entry_raises
    input = <<~BUNDLE
      ##############################
      BEGIN "only.txt"
      ##############################
      this is truncated
    BUNDLE

    assert_raises(Codeball::MalformedBundleError) do
      Codeball::Bundle.parse(input, config: @config)
    end
  end

  def test_extracts_content_with_border_like_content
    # Content that looks vaguely like a border but isn't
    input = <<~BUNDLE
      ##############################
      BEGIN "tricky.txt"
      ##############################
      some content
      --- not a border ---
      more content
      ##############################
      END "tricky.txt"
      ##############################
    BUNDLE

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 1, bundle.entries.length
    assert_includes bundle.entries.first.contents, "--- not a border ---"
  end

  def test_handles_empty_file_entries
    input = <<~BUNDLE
      ##############################
      BEGIN "empty.txt"
      ##############################
      ##############################
      END "empty.txt"
      ##############################
    BUNDLE

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 1, bundle.entries.length
    assert_empty bundle.entries.first.contents
  end

  def test_handles_path_without_quotes
    input = <<~BUNDLE
      ##############################
      BEGIN simple.txt
      ##############################
      content
      ##############################
      END simple.txt
      ##############################
    BUNDLE

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal "simple.txt", bundle.entries.first.path
  end

  def test_begin_marker_in_content_is_not_treated_as_new_entry
    # A BEGIN/END pair without borders should NOT create an entry.
    # Only BEGIN markers preceded by a border line are valid entry starts.
    input = <<~BUNDLE
      BEGIN "fake.txt"
      fake content
      END "fake.txt"
      ##############################
      BEGIN "real.txt"
      ##############################
      real content
      ##############################
      END "real.txt"
      ##############################
    BUNDLE

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 1, bundle.entries.length, "Should only find 1 entry (real.txt), not 2"
    assert_equal "real.txt", bundle.entries.first.path
    assert_equal "real content\n", bundle.entries.first.contents
  end
end
