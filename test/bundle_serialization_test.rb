require_relative "test_helper"

class BundleSerializationTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config = Codeball::Config.default
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_serialize_includes_border_and_content
    output = serialize_entry(path: "test.txt", contents: "hello")

    assert_includes output, @config.full_border
    assert_includes output, "hello"
  end

  def test_serialize_includes_begin_and_end_markers
    output = serialize_entry(path: "test.txt", contents: "hello")

    assert_includes output, 'BEGIN "test.txt"'
    assert_includes output, 'END "test.txt"'
  end

  def test_serialize_handles_empty_file
    entry = Codeball::Entry.new(path: "empty.txt", contents: "")
    bundle = Codeball::Bundle.new([entry], config: @config)

    output = capture_io { bundle.serialize }.first

    assert_includes output, 'BEGIN "empty.txt"'
    assert_includes output, 'END "empty.txt"'
  end

  def test_serialize_multiple_files_includes_first_entry_markers
    output = serialize_multiple_files

    assert_includes output, 'BEGIN "a.txt"'
    assert_includes output, 'END "a.txt"'
  end

  def test_serialize_multiple_files_includes_second_entry_markers
    output = serialize_multiple_files

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

  def test_serialize_includes_entry_with_non_text_mime_and_text_charset
    entry = Codeball::Entry.new(path: "code.md", contents: "var x = 1;")
    bundle = Codeball::Bundle.new([entry], config: @config)

    entry.stub(:mime_type, "application/javascript; charset=us-ascii") do
      output = capture_io { bundle.serialize }.first

      assert_includes output, 'BEGIN "code.md"'
      assert_includes output, "var x = 1;"
    end
  end

  def test_serialize_skips_non_text_without_trailing_blank_line
    text_entry = Codeball::Entry.new(path: "hello.txt", contents: "hello")
    non_text_entry = Codeball::Entry.new(path: "image.png", contents: "binary data")
    bundle = Codeball::Bundle.new([text_entry, non_text_entry], config: @config)

    non_text_entry.stub(:text?, false) do
      output = capture_io { bundle.serialize }.first

      assert_includes output, 'BEGIN "hello.txt"'
      refute_includes output, 'BEGIN "image.png"'
      refute output.end_with?("\n\n"), "Should not have trailing blank line after last entry"
    end
  end

  private

  def serialize_entry(path:, contents:)
    entry = Codeball::Entry.new(path: path, contents: contents)
    bundle = Codeball::Bundle.new([entry], config: @config)
    capture_io { bundle.serialize }.first
  end

  def serialize_multiple_files
    entries = [
      Codeball::Entry.new(path: "a.txt", contents: "aaa"),
      Codeball::Entry.new(path: "b.txt", contents: "bbb"),
    ]
    bundle = Codeball::Bundle.new(entries, config: @config)
    capture_io { bundle.serialize }.first
  end
end
