require_relative "../spec_helper"

RSpec.describe "codeball unpack", type: :integration do
  include CLIHelper

  let(:default_border) { "---\t" * 10 }

  def bundle_text_for(path, contents)
    header = "#{default_border}\nBEGIN #{path.inspect}\n#{default_border}\n"
    footer = "#{default_border}\nEND #{path.inspect}\n#{default_border}\n"
    "#{header}#{contents}#{footer}"
  end

  describe "extracting from a file argument" do
    let(:bundle) { pack_bundle(["hello.txt", "hello world\n"]) }
    let(:bundle_path) { create_file("bundle.txt", bundle) }
    let(:result) { run_codeball("unpack", "-o", "out", bundle_path) }

    it "writes the extracted file to disk" do
      result
      expect(read_output_file("out/hello.txt")).to eq("hello world\n")
    end

    it "prints a wrote summary to stdout" do
      expect(result.stdout).to include("wrote")
      expect(result.stdout).to include("hello.txt")
    end

    it "prints an extraction summary line" do
      expect(result.stdout).to include("---")
      expect(result.stdout).to include("extracted: 1")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "extracting from stdin" do
    let(:bundle) { pack_bundle(["greeting.txt", "hi there\n"]) }
    let(:result) { run_codeball("unpack", "-o", "out", stdin: bundle) }

    it "writes the extracted file to disk" do
      result
      expect(read_output_file("out/greeting.txt")).to eq("hi there\n")
    end
  end

  describe "extracting multiple files" do
    let(:bundle) do
      pack_bundle(
        ["one.txt", "first\n"],
        ["nested/two.txt", "second\n"],
      )
    end
    let(:result) { run_codeball("unpack", "-o", "out", stdin: bundle) }

    it "writes all files to disk" do
      result
      expect(read_output_file("out/one.txt")).to eq("first\n")
      expect(read_output_file("out/nested/two.txt")).to eq("second\n")
    end

    it "creates nested directories as needed" do
      result
      expect(output_path("out/nested/two.txt")).to exist
    end
  end

  describe "with --output-dir" do
    let(:bundle) { pack_bundle(["note.txt", "content\n"]) }
    let(:result) { run_codeball("unpack", "-o", "outdir", stdin: bundle) }

    it "writes files to the specified directory" do
      result
      expect(output_path("outdir/note.txt")).to exist
      expect(read_output_file("outdir/note.txt")).to eq("content\n")
    end
  end

  describe "with --output-dir pointing to a nonexistent directory" do
    let(:bundle) { pack_bundle(["data.txt", "stuff\n"]) }
    let(:result) { run_codeball("unpack", "-o", "deep/nested/dir", stdin: bundle) }

    it "creates the directory and writes files" do
      result
      expect(output_path("deep/nested/dir/data.txt")).to exist
      expect(read_output_file("deep/nested/dir/data.txt")).to eq("stuff\n")
    end
  end

  describe "with --dry-run" do
    let(:bundle) { pack_bundle(["phantom.txt", "invisible\n"]) }
    let(:result) { run_codeball("unpack", "--dry-run", "-o", "dryout", stdin: bundle) }

    it "does not create any files" do
      result
      expect(output_path("dryout")).not_to exist
    end

    it "prints dry-run prefixed output" do
      expect(result.stdout).to include("[dry-run]")
      expect(result.stdout).to include("would write:")
      expect(result.stdout).to include("phantom.txt")
    end

    it "prints the extraction summary" do
      expect(result.stdout).to include("[dry-run]")
      expect(result.stdout).to include("extracted: 1")
    end
  end

  describe "with --quiet" do
    let(:bundle) { pack_bundle(["silent.txt", "shh\n"]) }

    context "with a normal bundle" do
      let(:result) { run_codeball("unpack", "--quiet", "-o", "qout", stdin: bundle) }

      it "suppresses stdout output" do
        expect(result.stdout).to be_empty
      end

      it "still writes files to disk" do
        result
        expect(read_output_file("qout/silent.txt")).to eq("shh\n")
      end
    end

    context "with an unsafe path in the bundle" do
      let(:unsafe_bundle) { bundle_text_for("../escape.txt", "danger\n") }
      let(:result) { run_codeball("unpack", "--quiet", stdin: unsafe_bundle) }

      it "suppresses warnings on stderr" do
        expect(result.stderr).to be_empty
      end
    end
  end

  describe "with empty input" do
    let(:result) { run_codeball("unpack", stdin: "") }

    it "prints an error to stderr" do
      expect(result.stderr).to include("no input")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "with a bundle containing an unsafe path" do
    let(:unsafe_bundle) { bundle_text_for("../etc/passwd", "hacked\n") }
    let(:result) { run_codeball("unpack", stdin: unsafe_bundle) }

    it "skips the unsafe entry" do
      result
      expect(output_path("../etc/passwd")).not_to exist
    end

    it "prints a warning about the unsafe path" do
      expect(result.stderr).to include("warning:")
      expect(result.stderr).to include("unsafe path")
    end

    it "reports it in the skipped count" do
      expect(result.stdout).to include("skipped: 1")
    end
  end

  describe "with a truncated bundle" do
    let(:truncated_bundle) do
      valid = bundle_text_for("good.txt", "valid content\n")
      incomplete = "#{default_border}\nBEGIN \"orphan.txt\"\n#{default_border}\norphan content\n"
      valid + incomplete
    end
    let(:result) { run_codeball("unpack", stdin: truncated_bundle) }

    it "extracts valid entries" do
      result
      expect(read_output_file("good.txt")).to eq("valid content\n")
    end

    it "prints warnings about truncated entries" do
      expect(result.stderr).to include("warning:")
      expect(result.stderr).to include("truncated")
    end
  end

  describe "extracting an empty file" do
    let(:bundle) { pack_bundle(["blank.txt", ""]) }
    let(:result) { run_codeball("unpack", "-o", "out", stdin: bundle) }

    it "creates a zero-byte file on disk" do
      result
      expect(output_path("out/blank.txt")).to exist
      expect(output_path("out/blank.txt").size).to eq(0)
    end
  end

  describe "overwriting an existing file" do
    let(:bundle) { pack_bundle(["target.txt", "new content\n"]) }
    let(:result) do
      create_file("target.txt", "old content\n")
      run_codeball("unpack", stdin: bundle)
    end

    it "replaces the existing file contents" do
      result
      expect(read_output_file("target.txt")).to eq("new content\n")
    end
  end
end
