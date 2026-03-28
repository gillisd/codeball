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
    original = Codeball::Entry.new(path: "test.txt", contents: "hello world")
    bundle = Codeball::Bundle.new([original], config: @config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: @config)

    assert_equal 1, parsed.entries.length
    assert_equal "test.txt", parsed.entries.first.path
    assert_equal "hello world", parsed.entries.first.contents
  end

  def test_round_trip_multiple_files
    originals = [
      Codeball::Entry.new(path: "a.txt", contents: "aaa"),
      Codeball::Entry.new(path: "b.txt", contents: "bbb"),
      Codeball::Entry.new(path: "c.txt", contents: "ccc"),
    ]
    bundle = Codeball::Bundle.new(originals, config: @config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: @config)

    assert_equal 3, parsed.entries.length
    assert_equal "aaa", parsed.entries[0].contents
    assert_equal "bbb", parsed.entries[1].contents
    assert_equal "ccc", parsed.entries[2].contents
  end

  def test_round_trip_empty_file
    original = Codeball::Entry.new(path: "empty.txt", contents: "")
    bundle = Codeball::Bundle.new([original], config: @config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: @config)

    assert_equal 1, parsed.entries.length
    assert_empty parsed.entries.first.contents
  end

  def test_round_trip_empty_file_among_nonempty
    originals = [
      Codeball::Entry.new(path: "before.txt", contents: "before"),
      Codeball::Entry.new(path: "empty.txt", contents: ""),
      Codeball::Entry.new(path: "after.txt", contents: "after"),
    ]
    bundle = Codeball::Bundle.new(originals, config: @config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: @config)

    assert_equal 3, parsed.entries.length
    assert_equal "before", parsed.entries[0].contents
    assert_empty parsed.entries[1].contents
    assert_equal "after", parsed.entries[2].contents
  end

  def test_round_trip_nested_paths
    original = Codeball::Entry.new(path: "a/b/c/deep.txt", contents: "deep")
    bundle = Codeball::Bundle.new([original], config: @config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: @config)

    assert_equal "a/b/c/deep.txt", parsed.entries.first.path
  end

  def test_round_trip_with_custom_border
    custom_config = Codeball::Config.new(
      border: "###",
      border_width: 5,
      output_dir: @tmpdir,
      dry_run: false,
    )
    original = Codeball::Entry.new(path: "test.txt", contents: "custom border")
    bundle = Codeball::Bundle.new([original], config: custom_config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: custom_config)

    assert_equal "custom border", parsed.entries.first.contents
  end

  def test_round_trip_multiline_content
    content = "line 1\nline 2\nline 3\n"
    original = Codeball::Entry.new(path: "multi.txt", contents: content)
    bundle = Codeball::Bundle.new([original], config: @config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: @config)

    assert_equal content, parsed.entries.first.contents
  end

  def test_round_trip_content_with_special_characters
    content = "tabs\there\nnewlines\n\nand 'quotes' and \"double quotes\""
    original = Codeball::Entry.new(path: "special.txt", contents: content)
    bundle = Codeball::Bundle.new([original], config: @config)

    serialized = capture_io { bundle.serialize }.first
    parsed = Codeball::Bundle.parse(serialized, config: @config)

    assert_equal content, parsed.entries.first.contents
  end

  def test_full_round_trip_to_disk
    source_dir = File.join(@tmpdir, "source")
    dest_dir = File.join(@tmpdir, "dest")
    Dir.mkdir(source_dir)
    Dir.mkdir(dest_dir)

    File.write(File.join(source_dir, "a.txt"), "content a")
    File.write(File.join(source_dir, "b.txt"), "content b")
    FileUtils.touch(File.join(source_dir, "empty.txt"))

    Dir.chdir(source_dir) do
      files = Dir.glob("*")
      bundle = Codeball::Bundle.from_files(files, config: @config)
      @serialized = capture_io { bundle.serialize }.first
    end

    dest_config = Codeball::Config.new(
      border: @config.border,
      border_width: @config.border_width,
      output_dir: dest_dir,
      dry_run: false,
    )
    parsed = Codeball::Bundle.parse(@serialized, config: dest_config)
    capture_io { parsed.extract }

    %w[a.txt b.txt empty.txt].each do |basename|
      original = File.read(File.join(source_dir, basename))
      extracted = File.read(File.join(dest_dir, basename))

      assert_equal original, extracted, "Content mismatch for #{basename}"
    end
  end
end
