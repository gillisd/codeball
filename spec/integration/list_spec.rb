require_relative "../spec_helper"

RSpec.describe "codeball list", type: :integration do
  include CLIHelper

  describe "listing from a file argument" do
    it "prints a table with file paths and line counts" do
      skip "not yet implemented"
    end

    it "exits 0" do
      skip "not yet implemented"
    end
  end

  describe "listing from stdin" do
    it "prints a table with file paths and line counts" do
      skip "not yet implemented"
    end

    it "exits 0" do
      skip "not yet implemented"
    end
  end

  describe "with --show-border" do
    it "prints the detected border pattern" do
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

  describe "with a bundle containing multiple files" do
    it "lists all files" do
      skip "not yet implemented"
    end
  end

  describe "with a truncated bundle" do
    it "lists the valid entries" do
      skip "not yet implemented"
    end

    it "prints a warning about the truncated entry" do
      skip "not yet implemented"
    end

    it "exits 0 since valid entries were found" do
      skip "not yet implemented"
    end
  end

  describe "with a fully malformed bundle (no valid entries)" do
    it "prints an error to stderr" do
      skip "not yet implemented"
    end

    it "exits non-zero" do
      skip "not yet implemented"
    end
  end
end
