require "open3"
require "tmpdir"
require "pathname"
require "fileutils"
require_relative "support/have_output_line"

##
# Harness for running the codeball CLI as a subprocess.
#
# Every helper runs against +tmp_dir+, a per-example temp directory
# that is cleaned up automatically after each spec.
module CLIHelper
  CLIResult = Struct.new(:stdout, :stderr, :exit_code)

  PROJECT_ROOT = File.expand_path("..", __dir__).freeze
  EXE = File.join(PROJECT_ROOT, "exe/codeball").freeze
  RUBY_CMD = [RbConfig.ruby, "-I", File.join(PROJECT_ROOT, "lib"), EXE].freeze

  def run_codeball(*args, stdin: nil)
    stdout, stderr, status = Open3.capture3(
      *RUBY_CMD, *args,
      stdin_data: stdin,
      chdir: tmp_dir
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
    # Minimal PNG header -- detected as image/png by libmagic
    png_stub = ([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] + ([0] * 64)).pack("C*")
    File.binwrite(full, png_stub)
    full
  end

  def read_output_file(path)
    File.read(File.join(tmp_dir, path))
  end

  def output_path(path)
    Pathname.new(tmp_dir) / path
  end

  def pack_bundle(*file_pairs)
    file_pairs.each { |name, contents| create_file(name, contents) }
    names = file_pairs.map(&:first)
    result = run_codeball("pack", *names)
    raise "pack_bundle failed (exit #{result.exit_code}): #{result.stderr}" unless result.exit_code.zero?

    result.stdout
  end
end

RSpec.configure do |config|
  config.include CLIHelper, type: :integration

  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end

  config.after(:each, type: :integration) do
    FileUtils.rm_rf(@tmp_dir) if @tmp_dir
  end
end
