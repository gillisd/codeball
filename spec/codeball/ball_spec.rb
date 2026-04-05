require "codeball"

RSpec.describe Codeball::Ball do
  let(:hello_entry) { Codeball::Entry.new(path: "hello.rb", contents: "puts \"hello\"\n") }
  let(:greet_entry) { Codeball::Entry.new(path: "lib/greet.rb", contents: "def greet\n  \"hi\"\nend\n") }
  let(:binary_entry) { Codeball::Entry.new(path: "image.png", contents: "\x89PNG\r\n\x1A\n") }
  let(:ball_text) { hello_entry.serialize(Codeball::Border::SEPARATOR) + greet_entry.serialize(Codeball::Border::SEPARATOR) }

  describe ".parse" do
    context "with valid two-entry codeball text" do
      let(:ball) { described_class.parse(ball_text) }

      it "returns a Ball" do
        expect(ball).to be_a(described_class)
      end

      it "has no parse errors" do
        expect(ball.parse_error_count).to eq(0)
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
        expect { described_class.parse("this is not a codeball\njust random text\n") }
          .to raise_error(Codeball::MalformedBallError, /no content found/)
      end
    end

    context "with one valid entry and one truncated entry" do
      let(:truncated_text) do
        border = Codeball::Border::SEPARATOR
        valid = hello_entry.serialize(border)
        incomplete = "#{border}\nBEGIN \"orphan.rb\"\n#{border}\norphan content\n"
        valid + incomplete
      end
      let(:ball) { described_class.parse(truncated_text) }

      it "returns a Ball with one entry" do
        paths = []
        ball.each_entry { |e| paths << e.path }
        expect(paths).to eq(["hello.rb"])
      end

      it "has one parse error" do
        expect(ball.parse_error_count).to eq(1)
      end

      it "reports the truncation" do
        errors = []
        ball.each_parse_error { |msg| errors << msg }
        expect(errors.first).to include("truncated")
      end
    end

    context "with cursor injection" do
      let(:mock_cursor) { instance_double(Codeball::Cursor) }

      before do
        call_count = 0
        allow(mock_cursor).to receive(:finished?) { (call_count += 1) > 2 }
        allow(mock_cursor).to receive(:at_begin_marker?).and_return(true, false)
        allow(mock_cursor).to receive(:marker_path).and_return("injected.rb")
        allow(mock_cursor).to receive(:read_content_until_end).and_return("injected\n")
        allow(mock_cursor).to receive(:advance)
      end

      it "uses the injected cursor" do
        ball = described_class.parse(ball_text, cursor: mock_cursor)
        paths = []
        ball.each_entry { |e| paths << e.path }
        expect(paths).to eq(["injected.rb"])
      end
    end
  end

  describe ".new" do
    it "stores the entries" do
      ball = described_class.new([hello_entry, greet_entry])
      paths = []
      ball.each_entry { |e| paths << e.path }
      expect(paths).to eq(["hello.rb", "lib/greet.rb"])
    end
  end

  describe "#each_entry" do
    let(:ball) { described_class.new([hello_entry, greet_entry]) }

    it "yields each entry in order" do
      paths = []
      ball.each_entry { |e| paths << e.path }
      expect(paths).to eq(["hello.rb", "lib/greet.rb"])
    end
  end

  describe "#each_text_entry" do
    let(:ball) { described_class.new([hello_entry, binary_entry]) }

    it "yields only the text entry" do
      paths = []
      ball.each_text_entry { |e| paths << e.path }
      expect(paths).to eq(["hello.rb"])
    end
  end

  describe "#each_non_text_entry" do
    let(:ball) { described_class.new([hello_entry, binary_entry]) }

    it "yields only the binary entry" do
      paths = []
      ball.each_non_text_entry { |e| paths << e.path }
      expect(paths).to eq(["image.png"])
    end
  end

  describe "#each_parse_error" do
    let(:ball) { described_class.new([hello_entry], parse_errors: ["truncated entry for \"orphan.rb\""]) }

    it "yields the error message" do
      errors = []
      ball.each_parse_error { |msg| errors << msg }
      expect(errors).to eq(["truncated entry for \"orphan.rb\""])
    end
  end

  describe "#all_text?" do
    context "when all entries are text" do
      let(:ball) { described_class.new([hello_entry, greet_entry]) }

      it "returns true" do
        expect(ball.all_text?).to be true
      end
    end

    context "when any entry is binary" do
      let(:binary_entry) { Codeball::Entry.new(path: "image.png", contents: "\x89PNG\r\n\x1A\n") }
      let(:ball) { described_class.new([hello_entry, binary_entry]) }

      it "returns false" do
        expect(ball.all_text?).to be false
      end
    end
  end

  describe "#parse_error_count" do
    context "with no parse errors" do
      let(:ball) { described_class.new([hello_entry]) }

      it "returns 0" do
        expect(ball.parse_error_count).to eq(0)
      end
    end

    context "with two parse errors" do
      let(:ball) { described_class.new([hello_entry], parse_errors: ["error one", "error two"]) }

      it "returns 2" do
        expect(ball.parse_error_count).to eq(2)
      end
    end
  end

  describe "#serialize" do
    describe "output format" do
      let(:ball) { described_class.new([hello_entry]) }
      let(:output) { ball.serialize }

      it "includes the border, markers, and file contents" do
        expect(output).to include(Codeball::Border::SEPARATOR)
        expect(output).to include('BEGIN "hello.rb"')
        expect(output).to include('END "hello.rb"')
        expect(output).to include("puts \"hello\"\n")
      end
    end

    context "with a binary entry among text entries" do
      let(:binary_entry) { Codeball::Entry.new(path: "image.png", contents: "\x89PNG\r\n\x1A\n") }
      let(:ball) { described_class.new([hello_entry, binary_entry]) }

      it "does not include the binary entry" do
        expect(ball.serialize).not_to include("image.png")
      end
    end
  end
end
