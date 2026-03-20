require_relative "test_helper"

class BundleParsingTest < Minitest::Test
  include BundleTestHelper

  def setup
    @config = Codeball::Config.default
    @border = @config.full_border
  end

  def test_parse_single_file
    input = build_bundle(["test.txt", "hello"])

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 1, bundle.entries.length
    assert_equal "test.txt", bundle.entries.first.path
    assert_equal "hello", bundle.entries.first.contents
  end

  def test_parse_multiple_files
    input = build_bundle(["a.txt", "aaa"], ["b.txt", "bbb"])

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 2, bundle.entries.length
    assert_equal "a.txt", bundle.entries[0].path
    assert_equal "aaa", bundle.entries[0].contents
    assert_equal "b.txt", bundle.entries[1].path
    assert_equal "bbb", bundle.entries[1].contents
  end

  def test_parse_empty_file_content
    input = build_bundle(["empty.txt", ""])

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 1, bundle.entries.length
    assert_equal "empty.txt", bundle.entries.first.path
    assert_empty bundle.entries.first.contents
  end

  def test_parse_empty_file_among_nonempty
    input = build_bundle(["empty.txt", ""], ["nonempty.txt", "content"])

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal 2, bundle.entries.length
    assert_empty bundle.entries[0].contents
    assert_equal "content", bundle.entries[1].contents
  end

  def test_parse_raises_on_empty_input
    assert_raises(Codeball::MalformedBundleError) do
      Codeball::Bundle.parse("", config: @config)
    end
  end

  def test_parse_raises_on_whitespace_only_input
    assert_raises(Codeball::MalformedBundleError) do
      Codeball::Bundle.parse("   \n\n  ", config: @config)
    end
  end

  def test_parse_raises_on_malformed_segment_count
    input = "#{@border}\nBEGIN \"test.txt\"\n#{@border}\ncontent"

    assert_raises(Codeball::MalformedBundleError) do
      Codeball::Bundle.parse(input, config: @config)
    end
  end

  def test_parse_handles_nested_paths
    input = build_bundle(["a/b/c/deep.txt", "nested"])

    bundle = Codeball::Bundle.parse(input, config: @config)

    assert_equal "a/b/c/deep.txt", bundle.entries.first.path
  end

  def test_parse_with_custom_border
    custom_config = Codeball::Config.new(border: "###", border_width: 5, output_dir: ".", dry_run: false)
    custom_border = custom_config.full_border

    input = "#{custom_border}\n" +
            "BEGIN \"test.txt\"\n" +
            "#{custom_border}\n" +
            "content" +
            "#{custom_border}\n" +
            "END \"test.txt\"\n" +
            "#{custom_border}\n"

    bundle = Codeball::Bundle.parse(input, config: custom_config)

    assert_equal 1, bundle.entries.length
    assert_equal "content", bundle.entries.first.contents
  end

  def test_parse_with_regex_special_chars_in_border
    custom_config = Codeball::Config.new(border: "+++", border_width: 3, output_dir: ".", dry_run: false)
    custom_border = custom_config.full_border

    input = "#{custom_border}\n" +
            "BEGIN \"test.txt\"\n" +
            "#{custom_border}\n" +
            "content" +
            "#{custom_border}\n" +
            "END \"test.txt\"\n" +
            "#{custom_border}\n"

    bundle = Codeball::Bundle.parse(input, config: custom_config)

    assert_equal "content", bundle.entries.first.contents
  end
end
