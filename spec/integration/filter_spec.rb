require_relative "../spec_helper"

RSpec.describe "codeball filter", type: :integration do
  include CLIHelper

  # A ball with entries at several depths so glob semantics are observable.
  let(:bundle) do
    pack_bundle(
      ["lib/app.rb", "puts :app\n"],
      ["lib/nested/helper.rb", "puts :helper\n"],
      ["test/app_test.rb", "puts :test\n"],
      ["README.md", "# readme\n"],
    )
  end
  let(:bundle_path) { create_file("bundle.txt", bundle) }

  # Extract the entry paths from a serialized ball (BEGIN "path" lines).
  def entries_in(ball_text)
    ball_text.scan(/^BEGIN "(.+)"$/).flatten
  end

  describe "with a FILE argument and non-interactive stdin" do
    # Regression: the FILE argument must be honored even when stdin is not a
    # TTY (pipes, scripts, CI). Previously the file was ignored and treated
    # as another pattern, so this errored with "no input".
    let(:result) { run_codeball("filter", "lib/**/*.rb", bundle_path) }

    it "reads the ball from the file and keeps only matching entries" do
      expect(entries_in(result.stdout)).to contain_exactly("lib/app.rb", "lib/nested/helper.rb")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "reading from stdin" do
    let(:result) { run_codeball("filter", "lib/**/*.rb", stdin: bundle) }

    it "keeps only matching entries" do
      expect(entries_in(result.stdout)).to contain_exactly("lib/app.rb", "lib/nested/helper.rb")
    end
  end

  describe "glob semantics" do
    it "treats '*' as non-recursive (stops at '/')" do
      result = run_codeball("filter", "*.md", stdin: bundle)
      expect(entries_in(result.stdout)).to contain_exactly("README.md")
    end

    it "ORs multiple patterns together" do
      result = run_codeball("filter", "README.md", "test/**", stdin: bundle)
      expect(entries_in(result.stdout)).to contain_exactly("README.md", "test/app_test.rb")
    end
  end

  describe "with --inverse (-v)" do
    let(:result) { run_codeball("filter", "-v", "test/**", stdin: bundle) }

    it "keeps entries that do NOT match" do
      expect(entries_in(result.stdout)).to contain_exactly(
        "lib/app.rb", "lib/nested/helper.rb", "README.md"
      )
    end
  end

  describe "with empty input" do
    let(:result) { run_codeball("filter", "*.rb", stdin: "") }

    it "prints an error to stderr" do
      expect(result.stderr).to include("no input")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end

  describe "with a nonexistent trailing argument and no stdin" do
    # A trailing arg that is not a file is treated as another pattern; with
    # no piped ball there is nothing to filter, so the command fails loudly.
    let(:result) { run_codeball("filter", "*.rb", "no_such_ball.txt", stdin: "") }

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end

    it "reports no input on stderr" do
      expect(result.stderr).to include("no input")
    end
  end
end
