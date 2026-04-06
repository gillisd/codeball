require "codeball"

RSpec.describe Codeball::Stream do
  def serialize_entry(path, contents)
    border = Codeball::Border::SEPARATOR
    "#{border}\nBEGIN #{path.inspect}\n#{border}\n#{contents}#{border}\nEND #{path.inspect}\n#{border}\n"
  end

  let(:ball_text) do
    serialize_entry("hello.rb", "puts 'hello'\n") +
      serialize_entry("lib/greet.rb", "def greet\n  'hi'\nend\n")
  end

  context "with a valid two-entry codeball" do
    let(:entries) { described_class.new(cursor: Codeball::Cursor.new(ball_text)).to_a }

    it "emits two entries" do
      expect(entries.length).to eq(2)
    end

    it "first entry is valid with path hello.rb" do
      expect(entries[0].valid?).to be true
      expect(entries[0].path).to eq("hello.rb")
    end

    it "second entry is valid with path lib/greet.rb" do
      expect(entries[1].valid?).to be true
      expect(entries[1].path).to eq("lib/greet.rb")
    end

    it "first entry contents is the file content" do
      expect(entries[0].contents).to eq("puts 'hello'\n")
    end
  end

  context "with a truncated codeball" do
    let(:truncated_text) do
      border = Codeball::Border::SEPARATOR
      complete = serialize_entry("good.rb", "valid\n")
      incomplete = "#{border}\nBEGIN \"orphan.rb\"\n#{border}\norphan content\n"
      complete + incomplete
    end
    let(:entries) { described_class.new(cursor: Codeball::Cursor.new(truncated_text)).to_a }

    it "emits two entries" do
      expect(entries.length).to eq(2)
    end

    it "first entry is valid" do
      expect(entries[0].valid?).to be true
    end

    it "second entry is truncated" do
      expect(entries[1].truncated?).to be true
    end

    it "second entry has path from its Header" do
      expect(entries[1].path).to eq("orphan.rb")
    end
  end

  context "with a malformed codeball" do
    let(:mock_cursor) { instance_double(Codeball::Cursor) }
    let(:tokens) do
      [
        Codeball::Header.new("first.rb"),
        Codeball::Header.new("second.rb"),
        Codeball::Cursor::EOF,
      ]
    end

    before do
      call_count = 0
      allow(mock_cursor).to receive(:next_item) { tokens[call_count].tap { call_count += 1 } }
    end

    let(:entries) { described_class.new(cursor: mock_cursor).to_a }

    it "emits an errored entry" do
      errored = entries.select(&:errors?)
      expect(errored).not_to be_empty
    end

    it "the errored entry has errors" do
      errored = entries.find(&:errors?)
      expect(errored.errors?).to be true
    end

    it "the error message includes duplicate header" do
      errored = entries.find(&:errors?)
      expect(errored.error).to include("duplicate header")
    end
  end

  context "with empty text producing only EOF" do
    let(:entries) { described_class.new(cursor: Codeball::Cursor.new("")).to_a }

    it "emits no entries" do
      expect(entries).to be_empty
    end
  end

  describe "Enumerable" do
    let(:stream) { described_class.new(cursor: Codeball::Cursor.new(ball_text)) }

    it "responds to map" do
      expect(stream).to respond_to(:map)
    end

    it "responds to select" do
      expect(stream).to respond_to(:select)
    end

    it "responds to count" do
      expect(stream).to respond_to(:count)
    end
  end

  describe "#each_entry" do
    let(:stream) { described_class.new(cursor: Codeball::Cursor.new(ball_text)) }

    it "is aliased to each" do
      expect(stream.method(:each_entry)).to eq(stream.method(:each))
    end
  end
end
