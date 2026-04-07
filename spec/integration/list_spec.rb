require_relative "../spec_helper"

RSpec.describe "codeball list", type: :integration do
  include CLIHelper

  describe "listing from a file argument" do
    let(:bundle_text) { pack_bundle(["hello.rb", "puts 'hi'\n"]) }
    let(:bundle_file) { create_file("bundle.txt", bundle_text) }
    let(:result) { run_codeball("list", bundle_file) }

    it "prints a table with file paths and line counts" do
      expect(result.stdout).to include("File")
      expect(result.stdout).to include("hello.rb")
      expect(result.stdout).to include("1 lines")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "listing from stdin" do
    let(:bundle_text) { pack_bundle(["greeting.rb", "puts 'hello'\nputs 'world'\n"]) }
    let(:result) { run_codeball("list", stdin: bundle_text) }

    it "prints a table with file paths and line counts" do
      expect(result.stdout).to include("File")
      expect(result.stdout).to include("greeting.rb")
      expect(result.stdout).to include("2 lines")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "with empty input" do
    let(:result) { run_codeball("list", stdin: "") }

    it "prints an error to stderr" do
      expect(result.stderr).to include("no input")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "with a bundle containing multiple files" do
    let(:bundle_text) do
      pack_bundle(
        ["alpha.rb", "a = 1\n"],
        ["beta.rb", "b = 2\nb = 3\n"],
        ["gamma.rb", "c = 4\nc = 5\nc = 6\n"],
      )
    end
    let(:result) { run_codeball("list", stdin: bundle_text) }

    it "lists all files" do
      expect(result.stdout).to include("alpha.rb")
      expect(result.stdout).to include("beta.rb")
      expect(result.stdout).to include("gamma.rb")
      expect(result.stdout).to include("1 lines")
      expect(result.stdout).to include("2 lines")
      expect(result.stdout).to include("3 lines")
    end
  end

  describe "with a truncated bundle" do
    let(:full_bundle) do
      pack_bundle(
        ["complete.rb", "good = true\n"],
        ["truncated.rb", "this will be cut\n"],
      )
    end
    let(:truncated_bundle) { full_bundle[0...(full_bundle.rindex("END"))] }
    let(:result) { run_codeball("list", stdin: truncated_bundle) }

    it "lists the valid entries" do
      expect(result.stdout).to include("complete.rb")
    end

    it "prints a warning about the truncated entry" do
      expect(result.stderr).to include("warning:")
      expect(result.stderr).to include("truncated")
    end

    it "exits 0 since valid entries were found" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "with a fully malformed bundle (no valid entries)" do
    let(:result) { run_codeball("list", stdin: "this is not a bundle at all\njust garbage\n") }

    it "prints an error to stderr" do
      expect(result.stderr).to include("no content found")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end
end
