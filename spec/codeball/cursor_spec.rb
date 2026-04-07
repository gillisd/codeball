require "codeball"

RSpec.describe Codeball::Cursor do
  let(:hello_content) { "puts 'hello'\n" }
  let(:greet_content) { "def greet\n  'hi'\nend\n" }

  def serialize_entry(path, contents)
    border = Codeball::Border::SEPARATOR
    "#{border}\nBEGIN #{path.inspect}\n#{border}\n#{contents}#{border}\nEND #{path.inspect}\n#{border}\n"
  end

  let(:ball_text) { serialize_entry("hello.rb", hello_content) + serialize_entry("lib/greet.rb", greet_content) }
  let(:cursor) { described_class.new(ball_text) }

  describe "#next_item" do
    context "at the start of a valid codeball" do
      let(:first) { cursor.next_item }

      it "returns a Header" do
        expect(first).to be_a(Codeball::Header)
      end

      it "the Header wraps hello.rb" do
        expect(first.to_s).to eq("hello.rb")
      end
    end

    context "after a Header" do
      before { cursor.next_item }

      let(:second) { cursor.next_item }

      it "returns a Body" do
        expect(second).to be_a(Codeball::Body)
      end

      it "the Body wraps the file content" do
        expect(second.to_s).to eq(hello_content)
      end
    end

    context "after a Body" do
      before { 2.times { cursor.next_item } }

      let(:third) { cursor.next_item }

      it "returns a Footer" do
        expect(third).to be_a(Codeball::Footer)
      end

      it "the Footer wraps hello.rb" do
        expect(third.to_s).to eq("hello.rb")
      end
    end

    context "after a complete entry" do
      before { 3.times { cursor.next_item } }

      let(:fourth) { cursor.next_item }

      it "returns a Header for the second entry" do
        expect(fourth).to be_a(Codeball::Header)
      end

      it "the Header wraps lib/greet.rb" do
        expect(fourth.to_s).to eq("lib/greet.rb")
      end
    end

    context "at end of text" do
      before { 7.times { cursor.next_item } }

      it "returns EOF" do
        expect(cursor.next_item).to eq(Codeball::Cursor::EOF)
      end
    end

    context "with consecutive calls through entire text" do
      it "returns Header, Body, Footer, Header, Body, Footer, EOF in sequence" do
        types = Array.new(7) { cursor.next_item.class }
        expected = [
          Codeball::Header,
          Codeball::Body,
          Codeball::Footer,
          Codeball::Header,
          Codeball::Body,
          Codeball::Footer,
          Codeball::Cursor::EOF.class,
        ]
        expect(types).to eq(expected)
      end
    end

    context "with borders between tokens" do
      def collect_tokens(cursor)
        [].tap do |tokens|
          loop do
            token = cursor.next_item
            break if token == Codeball::Cursor::EOF

            tokens << token
          end
        end
      end

      it "never returns a border string as a token" do
        collect_tokens(cursor).each do |token|
          expect(Codeball::Border.recognize?(token.to_s))
            .to be(false), "Token #{token.class} was a border: #{token}"
        end
      end
    end

    context "with content that has no trailing newline" do
      let(:ball_text) { serialize_entry("no_nl.txt", "no newline") }

      it "returns a Body with border suffix stripped" do
        cursor.next_item
        body = cursor.next_item
        expect(body.to_s).to eq("no newline")
      end
    end

    context "with content containing a bare END marker with non-matching path" do
      let(:content) { "before\nEND \"other_file\"\nafter\n" }
      let(:ball_text) { serialize_entry("real.rb", content) }

      it "does not terminate body collection on the bare END" do
        cursor.next_item
        body = cursor.next_item
        expect(body.to_s).to eq(content)
      end
    end

    context "with content containing a bare END marker with matching path" do
      let(:content) { "before\nEND \"real.rb\"\nafter\n" }
      let(:ball_text) { serialize_entry("real.rb", content) }

      it "does not terminate body collection on the bare END" do
        cursor.next_item
        body = cursor.next_item
        expect(body.to_s).to eq(content)
      end
    end

    context "with whitespace-mangled borders" do
      let(:mangled_border) { "---  " * 10 }
      let(:ball_text) do
        b = mangled_border
        "#{b}\nBEGIN \"mangled.rb\"\n#{b}\nhello\n#{b}\nEND \"mangled.rb\"\n#{b}\n"
      end

      it "still produces Header, Body, Footer tokens" do
        tokens = []
        loop do
          token = cursor.next_item
          break if token == Codeball::Cursor::EOF

          tokens << token.class
        end
        expect(tokens).to eq([Codeball::Header, Codeball::Body, Codeball::Footer])
      end
    end
  end
end
