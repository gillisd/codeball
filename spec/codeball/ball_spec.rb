require "codeball"

RSpec.describe Codeball::Ball do
  def valid_entry(path: "hello.rb", contents: "puts 'hello'\n")
    entry = Codeball::Entry.new
    entry.header = Codeball::Header.new(path)
    entry.body = Codeball::Body.new(contents)
    entry.footer = Codeball::Footer.new(path)
    entry
  end

  def truncated_entry(path: "orphan.rb")
    entry = Codeball::Entry.new
    entry.header = Codeball::Header.new(path)
    entry
  end

  def errored_entry
    entry = Codeball::Entry.new
    entry.header = Codeball::Header.new("first.rb")
    entry.header = Codeball::Header.new("second.rb")
    entry
  end

  def binary_entry
    entry = valid_entry(path: "image.png", contents: "binary")
    allow(entry).to receive(:text?).and_return(false)
    entry
  end

  def serialize_entry(path, contents)
    border = Codeball::Border::SEPARATOR
    "#{border}\nBEGIN #{path.inspect}\n#{border}\n#{contents}#{border}\nEND #{path.inspect}\n#{border}\n"
  end

  let(:ball_text) do
    serialize_entry("hello.rb", "puts 'hello'\n") +
      serialize_entry("lib/greet.rb", "def greet\n  'hi'\nend\n")
  end

  describe ".parse" do
    context "with valid two-entry codeball text" do
      let(:ball) { described_class.parse(ball_text) }

      it "returns a Ball" do
        expect(ball).to be_a(described_class)
      end

      it "has no warnings" do
        expect(ball.warning_count).to eq(0)
      end
    end

    context "with empty text" do
      it "raises MalformedBallError" do
        expect { described_class.parse("") }.to raise_error(Codeball::MalformedBallError, /empty input/)
      end
    end

    context "with nil" do
      it "raises MalformedBallError" do
        expect { described_class.parse(nil) }.to raise_error(Codeball::MalformedBallError)
      end
    end

    context "with whitespace-only text" do
      it "raises MalformedBallError" do
        expect { described_class.parse("   \n\n  ") }.to raise_error(Codeball::MalformedBallError, /empty input/)
      end
    end

    context "with garbage text" do
      it "raises MalformedBallError" do
        expect { described_class.parse("not a codeball\n") }
          .to raise_error(Codeball::MalformedBallError, /no content found/)
      end
    end

    context "with a truncated codeball" do
      let(:truncated_text) do
        border = Codeball::Border::SEPARATOR
        complete = serialize_entry("hello.rb", "puts 'hello'\n")
        incomplete = "#{border}\nBEGIN \"orphan.rb\"\n#{border}\norphan content\n"
        complete + incomplete
      end
      let(:ball) { described_class.parse(truncated_text) }

      it "returns a Ball" do
        expect(ball).to be_a(described_class)
      end

      it "has one warning" do
        expect(ball.warning_count).to eq(1)
      end

      it "each_warning yields a truncation message" do
        warnings = []
        ball.each_warning { |w| warnings << w }
        expect(warnings.first).to include("truncated")
      end

      it "each_entry yields only the valid entry" do
        paths = []
        ball.each_entry { |e| paths << e.path }
        expect(paths).to eq(["hello.rb"])
      end
    end
  end

  describe ".new" do
    let(:ball) { described_class.new }

    it "creates an empty Ball" do
      entries = []
      ball.each_entry { |e| entries << e }
      expect(entries).to be_empty
    end

    it "has zero warnings" do
      expect(ball.warning_count).to eq(0)
    end
  end

  describe "#add_entry" do
    let(:ball) { described_class.new }

    context "with a valid entry" do
      before { ball.add_entry(valid_entry) }

      it "is retrievable via each_entry" do
        paths = []
        ball.each_entry { |e| paths << e.path }
        expect(paths).to eq(["hello.rb"])
      end

      it "does not add warnings" do
        expect(ball.warning_count).to eq(0)
      end
    end

    context "with an errored entry" do
      before { ball.add_entry(errored_entry) }

      it "adds the error to warnings" do
        warnings = []
        ball.each_warning { |w| warnings << w }
        expect(warnings.first).to include("duplicate header")
      end

      it "does not yield via each_entry" do
        entries = []
        ball.each_entry { |e| entries << e }
        expect(entries).to be_empty
      end
    end

    context "with a truncated entry" do
      before { ball.add_entry(truncated_entry) }

      it "adds a truncation warning" do
        warnings = []
        ball.each_warning { |w| warnings << w }
        expect(warnings.first).to include("truncated")
      end

      it "does not yield via each_entry" do
        entries = []
        ball.each_entry { |e| entries << e }
        expect(entries).to be_empty
      end
    end
  end

  describe "#each_entry" do
    let(:ball) { described_class.new }

    before do
      ball.add_entry(valid_entry(path: "hello.rb"))
      ball.add_entry(valid_entry(path: "lib/greet.rb", contents: "greet\n"))
    end

    it "yields valid entries in insertion order" do
      paths = []
      ball.each_entry { |e| paths << e.path }
      expect(paths).to eq(["hello.rb", "lib/greet.rb"])
    end

    it "first yielded entry has path hello.rb" do
      first = nil
      ball.each_entry { |e| first ||= e }
      expect(first.path).to eq("hello.rb")
    end
  end

  describe "#each_text_entry" do
    let(:ball) { described_class.new }

    before do
      ball.add_entry(valid_entry)
      ball.add_entry(binary_entry)
    end

    it "yields only text entries" do
      paths = []
      ball.each_text_entry { |e| paths << e.path }
      expect(paths).to eq(["hello.rb"])
    end
  end

  describe "#each_non_text_entry" do
    let(:ball) { described_class.new }

    before do
      ball.add_entry(valid_entry)
      ball.add_entry(binary_entry)
    end

    it "yields only non-text entries" do
      paths = []
      ball.each_non_text_entry { |e| paths << e.path }
      expect(paths).to eq(["image.png"])
    end
  end

  describe "#all_text?" do
    let(:ball) { described_class.new }

    context "when all entries are text" do
      before { ball.add_entry(valid_entry) }

      it "returns true" do
        expect(ball.all_text?).to be true
      end
    end

    context "when any entry is binary" do
      before do
        ball.add_entry(valid_entry)
        ball.add_entry(binary_entry)
      end

      it "returns false" do
        expect(ball.all_text?).to be false
      end
    end
  end

  describe "#serialize" do
    let(:ball) { described_class.new }

    describe "output format" do
      before { ball.add_entry(valid_entry) }

      it "includes border, markers, and content" do
        output = ball.serialize
        expect(output).to include(Codeball::Border::SEPARATOR)
        expect(output).to include('BEGIN "hello.rb"')
        expect(output).to include('END "hello.rb"')
        expect(output).to include("puts 'hello'\n")
      end
    end

    context "with a binary entry among text entries" do
      before do
        ball.add_entry(valid_entry)
        ball.add_entry(binary_entry)
      end

      it "does not include the binary entry" do
        expect(ball.serialize).not_to include("image.png")
      end
    end
  end

  describe "#validate!" do
    let(:ball) { described_class.new }

    context "with entries present" do
      before { ball.add_entry(valid_entry) }

      it "does not raise" do
        expect { ball.validate! }.not_to raise_error
      end
    end

    context "with no entries and no warnings" do
      it "raises MalformedBallError" do
        expect { ball.validate! }.to raise_error(Codeball::MalformedBallError, /no content found/)
      end
    end

    context "with no entries but warnings present" do
      before { ball.add_entry(truncated_entry) }

      it "raises MalformedBallError" do
        expect { ball.validate! }.to raise_error(Codeball::MalformedBallError, /no valid entries found/)
      end
    end
  end
end
