require_relative "test_helper"

class BundleExtractionTest < Minitest::Test
  include BundleTestHelper

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
