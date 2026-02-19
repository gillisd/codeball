require "minitest/activate"
require "tmpdir"
require "pathname"

require_relative "../lib/codeball"

class ConfigTest < Minitest::Test
  def test_default_config_values
    config = Codeball::Config.default

    assert_equal "---\t", config.border
    assert_equal 10, config.border_width
    assert_equal ".", config.output_dir
    refute_predicate config, :dry_run
  end

  def test_full_border_repeats_border_pattern
    config = Codeball::Config.new(border: "ab", border_width: 3, output_dir: ".", dry_run: false)

    assert_equal "ababab", config.full_border
  end

  def test_terminator_is_last_character_of_border
    config = Codeball::Config.new(border: "---\t", border_width: 1, output_dir: ".", dry_run: false)
    assert_equal "\t", config.terminator

    config = Codeball::Config.new(border: "###", border_width: 1, output_dir: ".", dry_run: false)
    assert_equal "#", config.terminator
  end
end

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
end

class BundleParsingTest < Minitest::Test
  def setup
    @config = Codeball::Config.default
    @border = @config.full_border
  end

  def build_bundle(*files)
    files.map do |path, contents|
      "#{@border}\n" +
      "BEGIN #{path.inspect}\n" +
      "#{@border}\n" +
      contents +
      "#{@border}\n" +
      "END #{path.inspect}\n" +
      "#{@border}\n"
    end.join("\n")
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

class BundleExtractionTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config = Codeball::Config.new(
      border: "---\t",
      border_width: 10,
      output_dir: @tmpdir,
      dry_run: false
    )
    @border = @config.full_border
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def build_bundle(*files)
    files.map do |path, contents|
      "#{@border}\n" +
      "BEGIN #{path.inspect}\n" +
      "#{@border}\n" +
      contents +
      "#{@border}\n" +
      "END #{path.inspect}\n" +
      "#{@border}\n"
    end.join("\n")
  end

  def test_extract_creates_files
    input = build_bundle(["test.txt", "hello"])
    bundle = Codeball::Bundle.parse(input, config: @config)

    capture_io { bundle.extract }

    assert_equal "hello", File.read(File.join(@tmpdir, "test.txt"))
  end

  def test_extract_creates_nested_directories
    input = build_bundle(["a/b/c/deep.txt", "nested"])
    bundle = Codeball::Bundle.parse(input, config: @config)

    capture_io { bundle.extract }

    assert_equal "nested", File.read(File.join(@tmpdir, "a/b/c/deep.txt"))
  end

  def test_extract_handles_empty_files
    input = build_bundle(["empty.txt", ""])
    bundle = Codeball::Bundle.parse(input, config: @config)

    capture_io { bundle.extract }

    assert_path_exists File.join(@tmpdir, "empty.txt")
    assert_empty File.read(File.join(@tmpdir, "empty.txt"))
  end

  def test_extract_skips_unsafe_paths
    input = build_bundle(["../escape.txt", "malicious"])
    bundle = Codeball::Bundle.parse(input, config: @config)

    summary = bundle.extract

    refute_path_exists File.join(@tmpdir, "../escape.txt")
    assert_equal 1, summary.skipped
  end

  def test_extract_dry_run_does_not_write
    dry_config = Codeball::Config.new(
      border: "---\t",
      border_width: 10,
      output_dir: @tmpdir,
      dry_run: true
    )
    input = build_bundle(["test.txt", "hello"])
    bundle = Codeball::Bundle.parse(input, config: dry_config)

    summary = bundle.extract

    refute_path_exists File.join(@tmpdir, "test.txt")
    assert_equal 1, summary.extracted
    assert_equal :dry_run, summary.results.first.status
  end

  def test_extract_returns_summary
    input = build_bundle(["good.txt", "ok"], ["../bad.txt", "nope"])
    bundle = Codeball::Bundle.parse(input, config: @config)

    summary = nil
    capture_io { summary = bundle.extract }

    assert_equal 1, summary.extracted
    assert_equal 1, summary.skipped
  end
end

class RoundTripTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config = Codeball::Config.new(
      border: "---\t",
      border_width: 10,
      output_dir: @tmpdir,
      dry_run: false
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
      Codeball::Entry.new(path: "c.txt", contents: "ccc")
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
      Codeball::Entry.new(path: "after.txt", contents: "after")
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
      dry_run: false
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
      files = Dir.glob("*").sort
      bundle = Codeball::Bundle.from_files(files, config: @config)
      @serialized = capture_io { bundle.serialize }.first
    end

    dest_config = Codeball::Config.new(
      border: @config.border,
      border_width: @config.border_width,
      output_dir: dest_dir,
      dry_run: false
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

    _out, err = capture_io do
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
