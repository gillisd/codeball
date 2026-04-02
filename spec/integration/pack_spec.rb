require_relative "../spec_helper"

RSpec.describe "codeball pack", type: :integration do
  include CLIHelper

  describe "packing a single file" do
    it "writes the bundle to stdout only, not to any file" do
      skip "not yet implemented"
    end

    it "writes bordered output to stdout" do
      skip "not yet implemented"
    end

    it "includes BEGIN and END markers with the file path" do
      skip "not yet implemented"
    end

    it "includes the file contents between markers" do
      skip "not yet implemented"
    end

    it "exits 0" do
      skip "not yet implemented"
    end
  end

  describe "packing multiple files" do
    it "includes all files in the output" do
      skip "not yet implemented"
    end

    it "separates entries with borders" do
      skip "not yet implemented"
    end
  end

  describe "stdout purity" do
    it "writes nothing to stderr on a successful pack" do
      skip "not yet implemented"
    end

    it "does not mix warnings into stdout when a binary file is skipped" do
      skip "not yet implemented"
    end
  end

  describe "with no file arguments" do
    it "prints an error to stderr" do
      skip "not yet implemented"
    end

    it "exits non-zero" do
      skip "not yet implemented"
    end
  end

  describe "with a nonexistent file" do
    it "prints a cannot-read warning to stderr" do
      skip "not yet implemented"
    end

    it "exits non-zero" do
      skip "not yet implemented"
    end
  end

  describe "with a binary file" do
    it "prints a skipping-non-text warning to stderr" do
      skip "not yet implemented"
    end

    it "exits non-zero" do
      skip "not yet implemented"
    end
  end

  describe "with --border and --border-width" do
    it "uses the custom border in output" do
      skip "not yet implemented"
    end
  end

  describe "with --quiet" do
    it "suppresses warnings to stderr" do
      skip "not yet implemented"
    end
  end

  describe "packing an empty file" do
    it "includes the entry with empty contents" do
      skip "not yet implemented"
    end
  end

  describe "packing files with nested paths" do
    it "preserves the relative path in BEGIN/END markers" do
      skip "not yet implemented"
    end
  end
end
