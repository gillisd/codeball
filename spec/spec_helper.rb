require "open3"
require "tmpdir"
require "pathname"
require "fileutils"

##
# Harness for running the codeball CLI as a subprocess.
#
# Every helper runs against +tmp_dir+, a per-example temp directory
# that is cleaned up automatically after each spec.
module CLIHelper
  CLIResult = Struct.new(:stdout, :stderr, :exit_code, keyword_init: true)

  EXE = File.expand_path("../../exe/codeball", __dir__).freeze
  RUBY_CMD = [RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), EXE].freeze

  def run_codeball(*args, stdin: nil)
    stdout, stderr, status = Open3.capture3(
      *RUBY_CMD, *args,
      stdin_data: stdin,
      chdir: tmp_dir,
    )
    CLIResult.new(stdout: stdout, stderr: stderr, exit_code: status.exitstatus)
  end

  def tmp_dir
    @tmp_dir ||= Dir.mktmpdir("codeball-spec")
  end

  def create_file(path, contents)
    full = File.join(tmp_dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, contents)
    full
  end

  def create_binary_file(path)
    full = File.join(tmp_dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    # Minimal PNG header — detected as image/png by libmagic
    File.binwrite(full, "\x89PNG\r\n\x1A\n" + ("\x00" * 64))
    full
  end

  def read_output_file(path)
    File.read(File.join(tmp_dir, path))
  end

  def pack_bundle(*file_pairs)
    paths = file_pairs.map { |name, contents| create_file(name, contents) }
    result = run_codeball("pack", *paths)
    raise "pack_bundle failed (exit #{result.exit_code}): #{result.stderr}" unless result.exit_code.zero?

    result.stdout
  end
end

RSpec.configure do |config|
  config.include CLIHelper, type: :integration

  config.after(:each, type: :integration) do
    FileUtils.rm_rf(@tmp_dir) if @tmp_dir
  end
end
