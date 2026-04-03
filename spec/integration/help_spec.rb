require_relative "../spec_helper"

RSpec.describe "codeball help", type: :integration do
  include CLIHelper

  describe "codeball with no arguments" do
    let(:result) { run_codeball }

    it "prints usage and available commands" do
      expect(result.stdout).to include("Usage: codeball")
      expect(result.stdout).to include("pack")
      expect(result.stdout).to include("unpack")
      expect(result.stdout).to include("list")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "codeball --help" do
    let(:result) { run_codeball("--help") }

    it "prints usage and available commands" do
      expect(result.stdout).to include("Usage: codeball")
      expect(result.stdout).to include("pack")
      expect(result.stdout).to include("unpack")
      expect(result.stdout).to include("list")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "codeball help" do
    let(:result) { run_codeball("help") }

    it "prints usage and available commands" do
      expect(result.stdout).to include("Usage: codeball")
      expect(result.stdout).to include("Commands:")
    end
  end

  describe "codeball pack --help" do
    let(:result) { run_codeball("pack", "--help") }

    it "prints pack usage with options and examples" do
      expect(result.stdout).to include("Usage: codeball pack")
      expect(result.stdout).to include("--border")
      expect(result.stdout).to include("--border-width")
      expect(result.stdout).to include("Examples:")
    end
  end

  describe "codeball list --help" do
    let(:result) { run_codeball("list", "--help") }

    it "prints list usage with options" do
      expect(result.stdout).to include("Usage: codeball list")
      expect(result.stdout).to include("--show-border")
    end
  end

  describe "codeball unpack --help" do
    let(:result) { run_codeball("unpack", "--help") }

    it "prints unpack usage with options" do
      expect(result.stdout).to include("Usage: codeball unpack")
      expect(result.stdout).to include("--output-dir")
      expect(result.stdout).to include("--dry-run")
    end
  end

  describe "codeball nonexistent" do
    let(:result) { run_codeball("nonexistent") }

    it "prints an error for unknown commands" do
      expect(result.stderr).to include("'nonexistent' is not a codeball command")
      expect(result.exit_code).not_to eq(0)
    end
  end
end
