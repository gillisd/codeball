require "codeball"
require "tmpdir"
require "fileutils"

RSpec.describe Codeball::Destination do
  def make_entry(path:, contents:)
    entry = Codeball::Entry.new
    entry.header = Codeball::Header.new(path)
    entry.body = Codeball::Body.new(contents)
    entry.footer = Codeball::Footer.new(path)
    entry
  end

  let(:tmp_dir) { Dir.mktmpdir("destination-spec") }
  let(:destination) { described_class.new(tmp_dir) }
  let(:hello_entry) { make_entry(path: "hello.rb", contents: "puts \"hello\"\n") }

  after { FileUtils.rm_rf(tmp_dir) }

  describe "#write" do
    context "with a normal entry" do
      let(:result) { destination.write(hello_entry) }

      describe "file system" do
        before { result }

        it "creates the file at the entry path" do
          expect(Pathname.new(tmp_dir) / "hello.rb").to exist
        end

        it "writes the entry contents to the file" do
          expect(File.read(File.join(tmp_dir, "hello.rb"))).to eq("puts \"hello\"\n")
        end
      end

      describe "return value" do
        it "returns status :written" do
          expect(result.status).to eq(:written)
        end

        it "returns the correct line count" do
          expect(result.line_count).to eq(1)
        end

        it "returns a path ending with the entry name" do
          expect(result.path.to_s).to end_with("hello.rb")
        end
      end
    end

    context "with a nested path" do
      let(:nested_entry) { make_entry(path: "lib/greet.rb", contents: "def greet; end\n") }
      let(:result) { destination.write(nested_entry) }

      describe "file system" do
        before { result }

        it "creates parent directories" do
          expect(Pathname.new(tmp_dir) / "lib").to exist
        end

        it "creates the file at the entry path" do
          expect(Pathname.new(tmp_dir) / "lib/greet.rb").to exist
        end
      end

      describe "return value" do
        it "returns status :written" do
          expect(result.status).to eq(:written)
        end
      end
    end

    context "with an empty entry" do
      let(:empty_entry) { make_entry(path: "empty.txt", contents: "") }
      let(:result) { destination.write(empty_entry) }

      describe "file system" do
        before { result }

        it "creates a zero-byte file" do
          path = Pathname.new(tmp_dir) / "empty.txt"
          expect(path).to exist
          expect(path.size).to eq(0)
        end
      end

      describe "return value" do
        it "returns status :written" do
          expect(result.status).to eq(:written)
        end

        it "returns line count 0" do
          expect(result.line_count).to eq(0)
        end
      end
    end

    context "with dry_run: true" do
      let(:destination) { described_class.new(tmp_dir, dry_run: true) }
      let(:result) { destination.write(hello_entry) }

      describe "file system" do
        before { result }

        it "does NOT create the file" do
          expect(Pathname.new(tmp_dir) / "hello.rb").not_to exist
        end
      end

      describe "return value" do
        it "returns status :dry_run" do
          expect(result.status).to eq(:dry_run)
        end

        it "returns the correct line count" do
          expect(result.line_count).to eq(1)
        end
      end
    end

    context "with an unsafe path starting with .." do
      let(:unsafe_entry) { make_entry(path: "../escape.txt", contents: "danger\n") }

      it "does NOT create any file" do
        destination.write(unsafe_entry)
        expect(Pathname.new(tmp_dir) / "../escape.txt").not_to exist
      end

      it "returns status :unsafe" do
        expect(destination.write(unsafe_entry).status).to eq(:unsafe)
      end
    end

    context "with an absolute path" do
      let(:absolute_entry) { make_entry(path: "/etc/passwd", contents: "hacked\n") }

      it "returns status :unsafe" do
        expect(destination.write(absolute_entry).status).to eq(:unsafe)
      end
    end

    context "with a home expansion path" do
      let(:home_entry) { make_entry(path: "~/evil.txt", contents: "danger\n") }

      it "returns status :unsafe" do
        expect(destination.write(home_entry).status).to eq(:unsafe)
      end
    end

    context "with a path traversal in the middle" do
      let(:traversal_entry) { make_entry(path: "foo/../../../etc/passwd", contents: "hacked\n") }

      it "returns status :unsafe" do
        expect(destination.write(traversal_entry).status).to eq(:unsafe)
      end
    end

    context "when the file write raises a system error" do
      let(:destination) { described_class.new("/dev/null/impossible") }
      let(:entry) { make_entry(path: "file.txt", contents: "content\n") }

      it "returns status :failed" do
        expect(destination.write(entry).status).to eq(:failed)
      end

      it "includes the error message" do
        expect(destination.write(entry).error).not_to be_nil
      end
    end

    it "yields the outcome to a block" do
      yielded = nil
      destination.write(hello_entry) { |outcome| yielded = outcome }
      expect(yielded.status).to eq(:written)
    end
  end

  describe "#summary" do
    it "aggregates write outcomes" do
      destination.write(hello_entry)
      summary = destination.summary(malformed: 1)
      expect(summary.extracted).to eq(1)
      expect(summary.malformed).to eq(1)
    end
  end

  describe "#write" do
    context "overwriting an existing file" do
      let(:new_entry) { make_entry(path: "hello.rb", contents: "new content\n") }

      before { File.write(File.join(tmp_dir, "hello.rb"), "old content") }

      describe "file system" do
        before { destination.write(new_entry) }

        it "replaces the file contents" do
          expect(File.read(File.join(tmp_dir, "hello.rb"))).to eq("new content\n")
        end
      end

      describe "return value" do
        it "returns status :written" do
          expect(destination.write(new_entry).status).to eq(:written)
        end
      end
    end
  end
end
