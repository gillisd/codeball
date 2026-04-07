require_relative "../spec_helper"

RSpec.describe "codeball pack", type: :integration do
  include CLIHelper

  describe "packing a single file" do
    let(:file_path) { create_file("hello.txt", "hello world\n") }
    let(:result) { run_codeball("pack", file_path) }

    it "writes the bundle to stdout only, not to any file" do
      expect(result.stdout).not_to be_empty
      expect(Dir.glob(File.join(tmp_dir, "*.codeball"))).to be_empty
    end

    it "writes bordered output to stdout" do
      expect(result.stdout).to include("---\t")
    end

    it "includes BEGIN and END markers with the file path" do
      expect(result.stdout).to include("BEGIN #{file_path.inspect}")
      expect(result.stdout).to include("END #{file_path.inspect}")
    end

    it "includes the file contents between markers" do
      expect(result.stdout).to include("hello world\n")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "packing multiple files" do
    let(:first_path) { create_file("one.txt", "first\n") }
    let(:second_path) { create_file("two.txt", "second\n") }
    let(:result) { run_codeball("pack", first_path, second_path) }

    it "includes all files in the output" do
      expect(result.stdout).to include("BEGIN #{first_path.inspect}")
      expect(result.stdout).to include("BEGIN #{second_path.inspect}")
    end

    it "separates entries with borders" do
      expect(result.stdout).to include("END #{first_path.inspect}")
      expect(result.stdout).to include("BEGIN #{second_path.inspect}")
    end
  end

  describe "stdout purity" do
    it "writes nothing to stderr on a successful pack" do
      path = create_file("clean.txt", "clean\n")
      result = run_codeball("pack", path)

      expect(result.stderr).to be_empty
    end

    it "does not mix warnings into stdout when a binary file is skipped" do
      text_path = create_file("good.txt", "good\n")
      binary_path = create_binary_file("image.png")
      result = run_codeball("pack", text_path, binary_path)

      expect(result.stdout).not_to include("skipping")
      expect(result.stdout).not_to include("codeball:")
    end
  end

  describe "with no file arguments" do
    let(:result) { run_codeball("pack") }

    it "prints an error to stderr" do
      expect(result.stderr).to include("insufficient number of arguments")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "with a nonexistent file" do
    let(:result) { run_codeball("pack", "/no/such/file.txt") }

    it "prints a cannot-read warning to stderr" do
      expect(result.stderr).to include("cannot read file:")
      expect(result.stderr).to include("/no/such/file.txt")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "with a binary file" do
    let(:binary_path) { create_binary_file("photo.png") }
    let(:result) { run_codeball("pack", binary_path) }

    it "prints a skipping-non-text warning to stderr" do
      expect(result.stderr).to include("skipping non-text file:")
      expect(result.stderr).to include("photo.png")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "with --quiet" do
    it "suppresses warnings to stderr" do
      binary_path = create_binary_file("quiet.png")
      result = run_codeball("pack", "--quiet", binary_path)

      expect(result.stderr).not_to include("skipping")
    end
  end

  describe "packing an empty file" do
    it "includes the entry with empty contents" do
      path = create_file("empty.txt", "")
      result = run_codeball("pack", path)

      expect(result.stdout).to include("BEGIN #{path.inspect}")
      expect(result.stdout).to include("END #{path.inspect}")
      expect(result.exit_code).to eq(0)
    end
  end

  describe "with a mix of valid and nonexistent files" do
    let(:valid_path) { create_file("exists.txt", "here\n") }
    let(:missing_path) { File.join(tmp_dir, "missing.txt") }
    let(:result) { run_codeball("pack", valid_path, missing_path) }

    it "packs the valid files to stdout" do
      expect(result.stdout).to include("BEGIN #{valid_path.inspect}")
      expect(result.stdout).to include("here\n")
    end

    it "warns about the invalid files on stderr" do
      expect(result.stderr).to include("cannot read file:")
      expect(result.stderr).to include("missing.txt")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "packing files with nested paths" do
    it "preserves the relative path in BEGIN/END markers" do
      path = create_file("lib/codeball/nested.rb", "module Nested; end\n")
      result = run_codeball("pack", path)

      expect(result.stdout).to include("BEGIN #{path.inspect}")
      expect(result.stdout).to include("END #{path.inspect}")
    end
  end
end
