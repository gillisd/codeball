require "codeball"

RSpec.describe Codeball::Cursor do
  let(:hello_entry) { Codeball::Entry.new(path: "hello.rb", contents: "puts \"hello\"\n") }
  let(:greet_entry) { Codeball::Entry.new(path: "lib/greet.rb", contents: "def greet\n  \"hi\"\nend\n") }
  let(:ball_text) { hello_entry.serialize + greet_entry.serialize }
  let(:cursor) { described_class.new(ball_text) }

  describe "#finished?" do
    context "at start of text" do
      it "returns false" do
        expect(cursor.finished?).to be false
      end
    end

    context "after advancing past all lines" do
      it "returns true" do
        cursor.advance until cursor.finished?
        expect(cursor.finished?).to be true
      end
    end
  end

  describe "#current_line" do
    context "at position 0" do
      it "returns the stripped first line of the text" do
        expect(cursor.current_line).to eq(ball_text.lines.first.strip)
      end
    end
  end

  describe "#advance" do
    it "increments position by one" do
      first = cursor.current_line
      cursor.advance
      expect(cursor.current_line).not_to eq(first)
    end
  end

  describe "#skip_borders" do
    context "when current line is a border" do
      it "advances past all consecutive border lines and stops at the first non-border line" do
        cursor.skip_borders
        expect(Codeball::Border.recognize?(cursor.current_line)).to be false
      end
    end
  end

  describe "#at_begin_marker?" do
    context "when current line is BEGIN preceded by a border" do
      it "returns true" do
        cursor.advance until cursor.current_line&.start_with?("BEGIN ")
        expect(cursor.at_begin_marker?).to be true
      end
    end

    context "when current line is BEGIN at position 0" do
      let(:cursor) { described_class.new("BEGIN \"hello.rb\"\ncontent\n") }

      it "returns false" do
        expect(cursor.at_begin_marker?).to be false
      end
    end

    context "when current line is not BEGIN" do
      it "returns false" do
        expect(cursor.at_begin_marker?).to be false
      end
    end
  end

  describe "#marker_path" do
    context "on a BEGIN line" do
      it "returns the path" do
        cursor.advance until cursor.current_line&.start_with?("BEGIN ")
        expect(cursor.marker_path).to eq("hello.rb")
      end
    end

    context "on a BEGIN line with single quotes" do
      let(:cursor) { described_class.new("#{Codeball::Border::SEPARATOR}\nBEGIN 'single.rb'\n") }

      it "returns the path" do
        cursor.advance
        expect(cursor.marker_path).to eq("single.rb")
      end
    end

    context "on a non-marker line" do
      it "returns nil" do
        expect(cursor.marker_path).to be_nil
      end
    end
  end

  describe "#read_content_until_end" do
    before { cursor.advance until cursor.at_begin_marker? }

    context "with a complete entry" do
      it "returns the content" do
        expect(cursor.read_content_until_end("hello.rb")).to eq("puts \"hello\"\n")
      end

      it "advances cursor past the END marker" do
        cursor.read_content_until_end("hello.rb")
        expect(cursor.finished?).to be(false)
      end
    end

    context "with a multi-line entry" do
      before do
        cursor.read_content_until_end("hello.rb")
        cursor.advance until cursor.at_begin_marker?
      end

      it "returns the full content" do
        expect(cursor.read_content_until_end("lib/greet.rb")).to eq("def greet\n  \"hi\"\nend\n")
      end
    end

    context "with a truncated entry (no END marker)" do
      let(:truncated) { "#{Codeball::Border::SEPARATOR}\nBEGIN \"orphan.rb\"\n#{Codeball::Border::SEPARATOR}\norphan content\n" }
      let(:cursor) { described_class.new(truncated) }

      before { cursor.advance until cursor.at_begin_marker? }

      it "returns nil" do
        expect(cursor.read_content_until_end("orphan.rb")).to be_nil
      end

      it "leaves cursor at finished" do
        cursor.read_content_until_end("orphan.rb")
        expect(cursor.finished?).to be true
      end
    end

    context "with an empty entry" do
      let(:empty_ball) do
        Codeball::Entry.new(path: "empty.txt", contents: "").serialize
      end
      let(:cursor) { described_class.new(empty_ball) }

      before { cursor.advance until cursor.at_begin_marker? }

      it "returns empty string" do
        expect(cursor.read_content_until_end("empty.txt")).to eq("")
      end
    end
  end

  describe "full parse walk" do
    def walk(cur)
      entries = []
      until cur.finished?
        next(cur.advance) unless cur.at_begin_marker?

        path = cur.marker_path
        content = cur.read_content_until_end(path)
        entries << [path, content] if content
      end
      entries
    end

    it "yields two entries with correct paths and content" do
      entries = walk(cursor)
      expect(entries.length).to eq(2)
      expect(entries[0]).to eq(["hello.rb", "puts \"hello\"\n"])
      expect(entries[1]).to eq(["lib/greet.rb", "def greet\n  \"hi\"\nend\n"])
    end
  end
end
