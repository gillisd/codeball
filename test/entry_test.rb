require_relative "test_helper"

class EntryTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @output_dir = Pathname.new(@tmpdir)
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

  def test_safe_for_rejects_dotdot_at_start
    entry = Codeball::Entry.new(path: "../etc/passwd", contents: "x")

    refute entry.safe_for?(@output_dir)
  end

  def test_safe_for_rejects_dotdot_in_middle
    entry = Codeball::Entry.new(path: "foo/../../../etc/passwd", contents: "x")

    refute entry.safe_for?(@output_dir)
  end

  def test_safe_for_rejects_absolute_paths
    entry = Codeball::Entry.new(path: "/etc/passwd", contents: "x")

    refute entry.safe_for?(@output_dir)
  end

  def test_safe_for_rejects_home_expansion
    entry = Codeball::Entry.new(path: "~/secret", contents: "x")

    refute entry.safe_for?(@output_dir)
  end

  def test_safe_for_rejects_empty_path
    entry = Codeball::Entry.new(path: "", contents: "x")

    refute entry.safe_for?(@output_dir)
  end

  def test_safe_for_rejects_whitespace_only_path
    entry = Codeball::Entry.new(path: "   ", contents: "x")

    refute entry.safe_for?(@output_dir)
  end

  def test_safe_for_accepts_simple_filename
    entry = Codeball::Entry.new(path: "file.txt", contents: "x")

    assert entry.safe_for?(@output_dir)
  end

  def test_safe_for_accepts_nested_path
    entry = Codeball::Entry.new(path: "a/b/c/file.txt", contents: "x")

    assert entry.safe_for?(@output_dir)
  end

  def test_resolved_path_joins_with_output_dir
    entry = Codeball::Entry.new(path: "sub/file.txt", contents: "x")

    resolved = entry.resolved_path(@output_dir)

    assert_equal @output_dir.join("sub/file.txt").expand_path, resolved
  end

  def test_write_to_creates_file
    entry = Codeball::Entry.new(path: "test.txt", contents: "hello")

    result = entry.write_to(@output_dir)

    assert_equal :written, result.status
    assert_equal "hello", File.read(@output_dir.join("test.txt"))
  end

  def test_write_to_creates_parent_directories
    entry = Codeball::Entry.new(path: "a/b/c/deep.txt", contents: "nested")

    result = entry.write_to(@output_dir)

    assert_equal :written, result.status
    assert_equal "nested", File.read(@output_dir.join("a/b/c/deep.txt"))
  end

  def test_write_to_dry_run_does_not_create_file
    entry = Codeball::Entry.new(path: "test.txt", contents: "hello")

    result = entry.write_to(@output_dir, dry_run: true)

    assert_equal :dry_run, result.status
    refute_path_exists @output_dir.join("test.txt")
  end

  def test_write_to_returns_unsafe_for_dangerous_paths
    entry = Codeball::Entry.new(path: "../escape.txt", contents: "malicious")

    result = entry.write_to(@output_dir)

    assert_equal :unsafe, result.status
    refute_path_exists @output_dir.join("../escape.txt")
  end
end
