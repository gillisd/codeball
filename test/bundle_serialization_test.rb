require_relative "test_helper"

class BundleSerializationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config = Codeball::Config.default
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_serialize_produces_bordered_output
    entry = Codeball::Entry.new(path: "test.txt", contents: "hello")
    bundle = Codeball::Bundle.new([entry], config: @config)

    output = capture_io { bundle.serialize }.first

    assert_includes output, @config.full_border
    assert_includes output, 'BEGIN "test.txt"'
    assert_includes output, "hello"
    assert_includes output, 'END "test.txt"'
  end

  def test_serialize_handles_empty_file
    entry = Codeball::Entry.new(path: "empty.txt", contents: "")
    bundle = Codeball::Bundle.new([entry], config: @config)

    output = capture_io { bundle.serialize }.first

    assert_includes output, 'BEGIN "empty.txt"'
    assert_includes output, 'END "empty.txt"'
  end

  def test_serialize_multiple_files_separated
    entries = [
      Codeball::Entry.new(path: "a.txt", contents: "aaa"),
      Codeball::Entry.new(path: "b.txt", contents: "bbb")
    ]
    bundle = Codeball::Bundle.new(entries, config: @config)

    output = capture_io { bundle.serialize }.first

    assert_includes output, 'BEGIN "a.txt"'
    assert_includes output, 'END "a.txt"'
    assert_includes output, 'BEGIN "b.txt"'
    assert_includes output, 'END "b.txt"'
  end

  def test_from_files_reads_actual_files
    File.write(File.join(@tmpdir, "real.txt"), "real content")

    bundle = Codeball::Bundle.from_files([File.join(@tmpdir, "real.txt")], config: @config)

    assert_equal 1, bundle.entries.length
    assert_equal "real content", bundle.entries.first.contents
  end

  def test_from_files_skips_nonexistent
    bundle = Codeball::Bundle.from_files(["/no/such/file.txt"], config: @config)

    assert_empty bundle.entries
  end

  def test_serialize_skips_non_text_without_trailing_blank_line
    text_entry = Codeball::Entry.new(path: "hello.txt", contents: "hello")
    non_text_entry = Codeball::Entry.new(path: "image.png", contents: "binary data")
    non_text_entry.define_singleton_method(:text?) { false }
    bundle = Codeball::Bundle.new([text_entry, non_text_entry], config: @config)

    output = capture_io { bundle.serialize }.first

    assert_includes output, 'BEGIN "hello.txt"'
    refute_includes output, 'BEGIN "image.png"'
    refute output.end_with?("\n\n"), "Should not have trailing blank line after last entry"
  end
end
