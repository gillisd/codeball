require_relative "test_helper"

class RoundTripTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config = Codeball::Config.new(
      border: "---\t",
      border_width: 10,
      output_dir: @tmpdir,
      dry_run: false,
    )
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_round_trip_single_file
    parsed = round_trip_entries(
      Codeball::Entry.new(path: "test.txt", contents: "hello world"),
    )

    assert_equal 1, parsed.entries.length
    assert_equal "test.txt", parsed.entries.first.path
    assert_equal "hello world", parsed.entries.first.contents
  end

  def test_round_trip_multiple_files_count
    parsed = round_trip_multiple_entries

    assert_equal 3, parsed.entries.length
  end

  def test_round_trip_multiple_files_contents
    parsed = round_trip_multiple_entries

    assert_equal "aaa", parsed.entries[0].contents
    assert_equal "bbb", parsed.entries[1].contents
    assert_equal "ccc", parsed.entries[2].contents
  end

  def test_round_trip_empty_file
    parsed = round_trip_entries(
      Codeball::Entry.new(path: "empty.txt", contents: ""),
    )

    assert_equal 1, parsed.entries.length
    assert_empty parsed.entries.first.contents
  end

  def test_round_trip_empty_file_among_nonempty_count
    parsed = round_trip_mixed_empty_entries

    assert_equal 3, parsed.entries.length
  end

  def test_round_trip_empty_file_among_nonempty_contents
    parsed = round_trip_mixed_empty_entries

    assert_equal "before", parsed.entries[0].contents
    assert_empty parsed.entries[1].contents
    assert_equal "after", parsed.entries[2].contents
  end

  def test_round_trip_nested_paths
    parsed = round_trip_entries(
      Codeball::Entry.new(path: "a/b/c/deep.txt", contents: "deep"),
    )

    assert_equal "a/b/c/deep.txt", parsed.entries.first.path
  end

  def test_round_trip_with_custom_border
    custom_config = Codeball::Config.new(
      border: "###",
      border_width: 5,
      output_dir: @tmpdir,
      dry_run: false,
    )
    parsed = round_trip_entries(
      Codeball::Entry.new(path: "test.txt", contents: "custom border"),
      config: custom_config,
    )

    assert_equal "custom border", parsed.entries.first.contents
  end

  def test_round_trip_multiline_content
    content = "first\nsecond\nthird\n"
    parsed = round_trip_entries(
      Codeball::Entry.new(path: "multi.txt", contents: content),
    )

    assert_equal content, parsed.entries.first.contents
  end

  def test_round_trip_content_with_special_characters
    content = "tabs\there\nnewlines\n\nand 'quotes' and \"double quotes\""
    parsed = round_trip_entries(
      Codeball::Entry.new(path: "special.txt", contents: content),
    )

    assert_equal content, parsed.entries.first.contents
  end

  def test_full_round_trip_to_disk
    source_dir = create_source_files
    dest_dir = create_dest_dir
    serialized = serialize_from_directory(source_dir)
    extract_to_directory(serialized, dest_dir)

    assert_files_match(source_dir, dest_dir)
  end

  private

  def round_trip_entries(*entries, config: @config)
    bundle = Codeball::Bundle.new(entries, config: config)
    serialized = capture_io { bundle.serialize }.first
    Codeball::Bundle.parse(serialized, config: config)
  end

  def round_trip_multiple_entries
    round_trip_entries(
      Codeball::Entry.new(path: "a.txt", contents: "aaa"),
      Codeball::Entry.new(path: "b.txt", contents: "bbb"),
      Codeball::Entry.new(path: "c.txt", contents: "ccc"),
    )
  end

  def round_trip_mixed_empty_entries
    round_trip_entries(
      Codeball::Entry.new(path: "before.txt", contents: "before"),
      Codeball::Entry.new(path: "empty.txt", contents: ""),
      Codeball::Entry.new(path: "after.txt", contents: "after"),
    )
  end

  def create_source_files
    source_dir = File.join(@tmpdir, "source")
    Dir.mkdir(source_dir)
    File.write(File.join(source_dir, "a.txt"), "content a")
    File.write(File.join(source_dir, "b.txt"), "content b")
    FileUtils.touch(File.join(source_dir, "empty.txt"))
    source_dir
  end

  def create_dest_dir
    dest_dir = File.join(@tmpdir, "dest")
    Dir.mkdir(dest_dir)
    dest_dir
  end

  def serialize_from_directory(source_dir)
    Dir.chdir(source_dir) do
      files = Dir.glob("*")
      bundle = Codeball::Bundle.from_files(files, config: @config)
      capture_io { bundle.serialize }.first
    end
  end

  def extract_to_directory(serialized, dest_dir)
    dest_config = Codeball::Config.new(
      border: @config.border,
      border_width: @config.border_width,
      output_dir: dest_dir,
      dry_run: false,
    )
    parsed = Codeball::Bundle.parse(serialized, config: dest_config)
    capture_io { parsed.extract }
  end

  def assert_files_match(source_dir, dest_dir)
    ["a.txt", "b.txt", "empty.txt"].each do |basename|
      original = File.read(File.join(source_dir, basename))
      extracted = File.read(File.join(dest_dir, basename))

      assert_equal original, extracted, "Content mismatch for #{basename}"
    end
  end
end
