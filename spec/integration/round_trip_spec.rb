require_relative "../spec_helper"

RSpec.describe "codeball pack | unpack round trip", type: :integration do
  include CLIHelper

  describe "single file" do
    it "preserves file contents through pack and unpack" do
      skip "not yet implemented"
    end
  end

  describe "multiple files" do
    it "preserves all file contents and paths" do
      skip "not yet implemented"
    end
  end

  describe "file with special characters" do
    it "preserves tabs, newlines, and quotes" do
      skip "not yet implemented"
    end
  end

  describe "nested directory structure" do
    it "recreates the directory tree" do
      skip "not yet implemented"
    end
  end

  describe "empty file among non-empty files" do
    it "preserves the empty file as zero bytes" do
      skip "not yet implemented"
    end
  end

  describe "with custom border options" do
    it "round-trips correctly with matching border args on both sides" do
      skip "not yet implemented"
    end
  end

  describe "pack to file, then unpack from file" do
    it "works with intermediate file instead of pipe" do
      skip "not yet implemented"
    end
  end

  describe "unicode and multibyte content" do
    it "preserves CJK characters" do
      skip "not yet implemented"
    end

    it "preserves emoji" do
      skip "not yet implemented"
    end

    it "preserves combining marks" do
      skip "not yet implemented"
    end
  end

  describe "large file" do
    it "round-trips a 10,000 line file without error" do
      skip "not yet implemented"
    end
  end
end
