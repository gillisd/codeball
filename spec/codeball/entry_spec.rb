require "codeball"
require "tmpdir"
require "fileutils"

RSpec.describe Codeball::Entry do
  context "when newly created" do
    let(:entry) { described_class.new }

    it "is not valid" do
      expect(entry.valid?).to be false
    end

    it "is incomplete" do
      expect(entry.incomplete?).to be true
    end

    it "has no errors" do
      expect(entry.errors?).to be false
    end

    it "is not truncated" do
      expect(entry.truncated?).to be false
    end

    it "has nil path" do
      expect(entry.path).to be_nil
    end

    it "has nil contents" do
      expect(entry.contents).to be_nil
    end
  end

  describe "#header=" do
    let(:entry) { described_class.new }

    context "setting header once" do
      before { entry.header = Codeball::Header.new("hello.rb") }

      it "sets path to hello.rb" do
        expect(entry.path).to eq("hello.rb")
      end

      it "remains incomplete" do
        expect(entry.incomplete?).to be true
      end
    end

    context "setting header twice" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.header = Codeball::Header.new("other.rb")
      end

      it "has errors" do
        expect(entry.errors?).to be true
      end

      it "error includes duplicate header" do
        expect(entry.error).to include("duplicate header")
      end
    end
  end

  describe "#body=" do
    let(:entry) { described_class.new }

    context "setting body once" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("puts 'hello'\n")
      end

      it "sets contents" do
        expect(entry.contents).to eq("puts 'hello'\n")
      end

      it "remains incomplete" do
        expect(entry.incomplete?).to be true
      end
    end

    context "setting body twice" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("first")
        entry.body = Codeball::Body.new("second")
      end

      it "has errors" do
        expect(entry.errors?).to be true
      end

      it "error includes duplicate body" do
        expect(entry.error).to include("duplicate body")
      end
    end
  end

  describe "#footer=" do
    let(:entry) { described_class.new }

    context "setting footer that matches header" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("puts 'hello'\n")
        entry.footer = Codeball::Footer.new("hello.rb")
      end

      it "is valid" do
        expect(entry.valid?).to be true
      end

      it "is not incomplete" do
        expect(entry.incomplete?).to be false
      end
    end

    context "setting footer that does not match header" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("puts 'hello'\n")
        entry.footer = Codeball::Footer.new("wrong.rb")
      end

      it "is not valid" do
        expect(entry.valid?).to be false
      end

      it "has errors" do
        expect(entry.errors?).to be true
      end
    end

    context "setting footer twice" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("content")
        entry.footer = Codeball::Footer.new("hello.rb")
        entry.footer = Codeball::Footer.new("hello.rb")
      end

      it "has errors" do
        expect(entry.errors?).to be true
      end

      it "error includes duplicate footer" do
        expect(entry.error).to include("duplicate footer")
      end
    end
  end

  describe "#truncated?" do
    let(:entry) { described_class.new }

    context "with header and body but no footer" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("content")
      end

      it "is truncated" do
        expect(entry.truncated?).to be true
      end
    end

    context "with header only" do
      before { entry.header = Codeball::Header.new("hello.rb") }

      it "is truncated" do
        expect(entry.truncated?).to be true
      end
    end

    context "when valid" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("content")
        entry.footer = Codeball::Footer.new("hello.rb")
      end

      it "is not truncated" do
        expect(entry.truncated?).to be false
      end
    end

    context "when errored" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.header = Codeball::Header.new("other.rb")
      end

      it "is not truncated" do
        expect(entry.truncated?).to be false
      end
    end
  end

  describe "#serialize" do
    context "when valid" do
      let(:entry) { described_class.new }

      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("puts 'hello'\n")
        entry.footer = Codeball::Footer.new("hello.rb")
      end

      it "includes border, markers, and content" do
        output = entry.serialize
        expect(output).to include(Codeball::Border::SEPARATOR)
        expect(output).to include('BEGIN "hello.rb"')
        expect(output).to include('END "hello.rb"')
        expect(output).to include("puts 'hello'\n")
      end
    end
  end

  describe "#text?" do
    let(:entry) { described_class.new }

    context "with text content" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("puts 'hello'\n")
        entry.footer = Codeball::Footer.new("hello.rb")
      end

      it "returns true" do
        expect(entry.text?).to be true
      end
    end

    context "with binary content" do
      before do
        entry.header = Codeball::Header.new("image.png")
        entry.body = Codeball::Body.new("binary")
        entry.footer = Codeball::Footer.new("image.png")
        allow(entry).to receive(:text?).and_return(false)
      end

      it "returns false" do
        expect(entry.text?).to be false
      end
    end

    context "with empty content" do
      before do
        entry.header = Codeball::Header.new("empty.txt")
        entry.body = Codeball::Body.new("")
        entry.footer = Codeball::Footer.new("empty.txt")
      end

      it "returns true" do
        expect(entry.text?).to be true
      end
    end
  end

  describe "#line_count" do
    let(:entry) { described_class.new }

    context "with single line ending in newline" do
      before do
        entry.header = Codeball::Header.new("hello.rb")
        entry.body = Codeball::Body.new("puts 'hello'\n")
        entry.footer = Codeball::Footer.new("hello.rb")
      end

      it "returns 1" do
        expect(entry.line_count).to eq(1)
      end
    end

    context "with empty contents" do
      before do
        entry.header = Codeball::Header.new("empty.txt")
        entry.body = Codeball::Body.new("")
        entry.footer = Codeball::Footer.new("empty.txt")
      end

      it "returns 0" do
        expect(entry.line_count).to eq(0)
      end
    end
  end

  describe ".from_file" do
    let(:tmp_dir) { Dir.mktmpdir("entry-spec") }

    after { FileUtils.rm_rf(tmp_dir) }

    context "with a readable file" do
      let(:file_path) { File.join(tmp_dir, "hello.rb") }

      before { File.write(file_path, "puts 'hello'\n") }

      it "returns a valid Entry" do
        expect(described_class.from_file(file_path).valid?).to be true
      end

      it "has the file path" do
        expect(described_class.from_file(file_path).path).to eq(file_path)
      end

      it "has the file contents" do
        expect(described_class.from_file(file_path).contents).to eq("puts 'hello'\n")
      end
    end

    context "with a nonexistent file" do
      it "returns nil" do
        expect(described_class.from_file("/nonexistent/path")).to be_nil
      end
    end

    context "with an empty file" do
      let(:file_path) { File.join(tmp_dir, "empty.txt") }

      before { FileUtils.touch(file_path) }

      it "returns a valid Entry" do
        expect(described_class.from_file(file_path).valid?).to be true
      end

      it "has empty contents" do
        expect(described_class.from_file(file_path).contents).to eq("")
      end
    end
  end
end
