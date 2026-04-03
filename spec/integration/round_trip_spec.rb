require_relative "../spec_helper"

RSpec.describe "codeball pack | unpack round trip", type: :integration do
  include CLIHelper

  describe "single file" do
    let(:content) { "puts 'hello world'\n" }

    before { create_file("hello.rb", content) }

    it "preserves file contents through pack and unpack" do
      pack_result = run_codeball("pack", "hello.rb")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("hello.rb")).to eq(content)
    end
  end

  describe "multiple files" do
    let(:content_a) { "class Foo; end\n" }
    let(:content_b) { "class Bar; end\n" }

    before do
      create_file("foo.rb", content_a)
      create_file("bar.rb", content_b)
    end

    it "preserves all file contents and paths" do
      pack_result = run_codeball("pack", "foo.rb", "bar.rb")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("foo.rb")).to eq(content_a)
      expect(read_output_file("bar.rb")).to eq(content_b)
    end
  end

  describe "file with special characters" do
    let(:content) { "col1\tcol2\nline \"two\"\nline 'three'\n" }

    before { create_file("special.txt", content) }

    it "preserves tabs, newlines, and quotes" do
      pack_result = run_codeball("pack", "special.txt")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("special.txt")).to eq(content)
    end
  end

  describe "nested directory structure" do
    let(:content) { "module Nested; end\n" }

    before { create_file("lib/codeball/nested.rb", content) }

    it "recreates the directory tree" do
      pack_result = run_codeball("pack", "lib/codeball/nested.rb")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("lib/codeball/nested.rb")).to eq(content)
    end
  end

  describe "empty file among non-empty files" do
    let(:nonempty_content) { "something\n" }

    before do
      create_file("nonempty.rb", nonempty_content)
      create_file("empty.rb", "")
    end

    it "preserves the empty file as zero bytes" do
      pack_result = run_codeball("pack", "nonempty.rb", "empty.rb")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("nonempty.rb")).to eq(nonempty_content)
      expect(read_output_file("empty.rb")).to eq("")
    end
  end

  describe "with custom border options" do
    let(:content) { "custom border test\n" }

    before { create_file("bordered.txt", content) }

    it "round-trips correctly with matching border args on both sides" do
      pack_result = run_codeball("pack", "--border", "###", "--border-width", "5", "bordered.txt")
      run_codeball("unpack", "--border", "###", "--border-width", "5", stdin: pack_result.stdout)

      expect(read_output_file("bordered.txt")).to eq(content)
    end
  end

  describe "pack to file, then unpack from file" do
    let(:content) { "file-based round trip\n" }

    before { create_file("original.rb", content) }

    it "works with intermediate file instead of pipe" do
      pack_result = run_codeball("pack", "original.rb")
      create_file("bundle.txt", pack_result.stdout)
      bundle_path = File.join(tmp_dir, "bundle.txt")

      run_codeball("unpack", bundle_path)

      expect(read_output_file("original.rb")).to eq(content)
    end
  end

  describe "unicode and multibyte content" do
    it "preserves CJK characters" do
      content = "こんにちは世界\n"
      create_file("cjk.txt", content)

      pack_result = run_codeball("pack", "cjk.txt")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("cjk.txt")).to eq(content)
    end

    it "preserves emoji" do
      content = "🎉🚀💎\n"
      create_file("emoji.txt", content)

      pack_result = run_codeball("pack", "emoji.txt")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("emoji.txt")).to eq(content)
    end

    it "preserves combining marks" do
      content = "e\u0301 is e with acute\n"
      create_file("combining.txt", content)

      pack_result = run_codeball("pack", "combining.txt")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("combining.txt")).to eq(content)
    end
  end

  describe "file containing border-like content" do
    let(:content) { "before\n----------\n###########\n~~~~~~~~~~\nafter\n" }

    before { create_file("borders.txt", content) }

    it "preserves content that looks like a border line" do
      pack_result = run_codeball("pack", "borders.txt")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("borders.txt")).to eq(content)
    end
  end

  describe "file containing BEGIN/END markers in content" do
    let(:content) { "BEGIN \"foo\"\nsome middle text\nEND \"foo\"\n" }

    before { create_file("markers.txt", content) }

    it "preserves content that contains BEGIN and END keywords" do
      pack_result = run_codeball("pack", "markers.txt")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("markers.txt")).to eq(content)
    end
  end

  describe "file without trailing newline" do
    let(:content) { "no newline at end" }

    before { create_file("no_newline.txt", content) }

    it "preserves the exact content without adding a newline" do
      pack_result = run_codeball("pack", "no_newline.txt")
      run_codeball("unpack", stdin: pack_result.stdout)

      expect(read_output_file("no_newline.txt")).to eq(content)
    end
  end

  describe "large file" do
    let(:content) { (1..10_000).map { |i| "line #{i}: #{("x" * 40)}\n" }.join }

    before { create_file("large.txt", content) }

    it "round-trips a 10,000 line file without error" do
      pack_result = run_codeball("pack", "large.txt")
      expect(pack_result.exit_code).to eq(0)

      unpack_result = run_codeball("unpack", stdin: pack_result.stdout)
      expect(unpack_result.exit_code).to eq(0)

      expect(read_output_file("large.txt")).to eq(content)
    end
  end
end
