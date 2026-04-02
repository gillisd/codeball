require_relative "../spec_helper"

RSpec.describe "codeball unpack", type: :integration do
  include CLIHelper

  describe "extracting from a file argument" do
    it "writes the extracted file to disk" do
      skip "not yet implemented"
    end

    it "prints a wrote summary to stdout" do
      skip "not yet implemented"
    end

    it "prints an extraction summary line" do
      skip "not yet implemented"
    end

    it "exits 0" do
      skip "not yet implemented"
    end
  end

  describe "extracting from stdin" do
    it "writes the extracted file to disk" do
      skip "not yet implemented"
    end
  end

  describe "extracting multiple files" do
    it "writes all files to disk" do
      skip "not yet implemented"
    end

    it "creates nested directories as needed" do
      skip "not yet implemented"
    end
  end

  describe "with --output-dir" do
    it "writes files to the specified directory" do
      skip "not yet implemented"
    end
  end

  describe "with --output-dir pointing to a nonexistent directory" do
    it "creates the directory and writes files" do
      skip "not yet implemented"
    end
  end

  describe "with --dry-run" do
    it "does not create any files" do
      skip "not yet implemented"
    end

    it "prints dry-run prefixed output" do
      skip "not yet implemented"
    end

    it "prints the extraction summary" do
      skip "not yet implemented"
    end
  end

  describe "with --quiet" do
    it "suppresses stdout output" do
      skip "not yet implemented"
    end

    it "still writes files to disk" do
      skip "not yet implemented"
    end
  end

  describe "with empty input" do
    it "prints an error to stderr" do
      skip "not yet implemented"
    end

    it "exits non-zero" do
      skip "not yet implemented"
    end
  end

  describe "with a bundle containing an unsafe path" do
    it "skips the unsafe entry" do
      skip "not yet implemented"
    end

    it "prints a warning about the unsafe path" do
      skip "not yet implemented"
    end

    it "reports it in the skipped count" do
      skip "not yet implemented"
    end
  end

  describe "with a truncated bundle" do
    it "extracts valid entries" do
      skip "not yet implemented"
    end

    it "prints warnings about truncated entries" do
      skip "not yet implemented"
    end
  end

  describe "extracting an empty file" do
    it "creates a zero-byte file on disk" do
      skip "not yet implemented"
    end
  end

  describe "overwriting an existing file" do
    it "replaces the existing file contents" do
      skip "not yet implemented"
    end
  end
end
