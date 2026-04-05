require_relative "test_helper"

class EntryTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_from_file_reads_content
    path = File.join(@tmpdir, "test.txt")
    File.write(path, "hello world")

    entry = Codeball::Entry.from_file(path)

    assert_equal "test.txt", File.basename(entry.path)
    assert_equal "hello world", entry.contents
  end

  def test_from_file_returns_nil_for_nonexistent
    entry = Codeball::Entry.from_file("/nonexistent/path/file.txt")

    assert_nil entry
  end

  def test_from_file_handles_empty_files
    path = File.join(@tmpdir, "empty.txt")
    FileUtils.touch(path)

    entry = Codeball::Entry.from_file(path)

    assert_empty entry.contents
    assert_predicate entry, :empty?
    assert_equal 0, entry.byte_size
  end

  def test_byte_size_returns_content_length
    entry = Codeball::Entry.new(path: "test.txt", contents: "hello")

    assert_equal 5, entry.byte_size
  end

  def test_empty_predicate
    empty = Codeball::Entry.new(path: "empty.txt", contents: "")
    nonempty = Codeball::Entry.new(path: "nonempty.txt", contents: "x")

    assert_predicate empty, :empty?
    refute_predicate nonempty, :empty?
  end

  def test_empty_entry_is_text
    entry = Codeball::Entry.new(path: "empty.txt", contents: "")

    assert_predicate entry, :text?
  end

  def test_text_for_non_text_mime_with_text_charset
    entry = Codeball::Entry.new(path: "code.md", contents: "var x = 1;")

    entry.stub(:mime_type, "application/javascript; charset=us-ascii") do
      assert_predicate entry, :text?
    end
  end

  def test_not_text_for_binary_charset
    entry = Codeball::Entry.new(path: "image.png", contents: "PNG\r\n".b)

    entry.stub(:mime_type, "image/png; charset=binary") do
      refute_predicate entry, :text?
    end
  end

  def test_entries_share_magic_client_by_default
    a = Codeball::Entry.new(path: "a.txt", contents: "aaa")
    b = Codeball::Entry.new(path: "b.txt", contents: "bbb")

    assert_same a.send(:magic_client), b.send(:magic_client)
  end

  def test_rejects_empty_path_at_initialization
    assert_raises(ArgumentError) do
      Codeball::Entry.new(path: "", contents: "x")
    end
  end

  def test_rejects_whitespace_only_path_at_initialization
    assert_raises(ArgumentError) do
      Codeball::Entry.new(path: "   ", contents: "x")
    end
  end
end
