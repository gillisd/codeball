require_relative "../spec_helper"

RSpec.describe "codeball help", type: :integration do
  include CLIHelper

  describe "codeball with no arguments" do
    it "prints usage and available commands" do
      skip "not yet implemented"
    end

    it "exits non-zero" do
      skip "not yet implemented"
    end
  end

  describe "codeball --help" do
    it "prints usage and available commands" do
      skip "not yet implemented"
    end

    it "exits 0" do
      skip "not yet implemented"
    end
  end

  describe "codeball help" do
    it "prints usage and available commands" do
      skip "not yet implemented"
    end
  end

  describe "codeball pack --help" do
    it "prints pack usage with options and examples" do
      skip "not yet implemented"
    end
  end

  describe "codeball list --help" do
    it "prints list usage with options" do
      skip "not yet implemented"
    end
  end

  describe "codeball unpack --help" do
    it "prints unpack usage with options" do
      skip "not yet implemented"
    end
  end

  describe "codeball nonexistent" do
    it "prints an error for unknown commands" do
      skip "not yet implemented"
    end
  end
end
