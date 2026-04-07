require "codeball"

RSpec.describe Codeball::Border do
  describe "SEPARATOR" do
    it "equals the border pattern repeated 10 times" do
      expect(described_class::SEPARATOR).to eq("---\t" * 10)
      expect(described_class::SEPARATOR.length).to eq(40)
    end
  end

  describe ".recognize?" do
    context "with a line of repeated dashes" do
      it "returns true" do
        expect(described_class.recognize?("----------")).to be true
      end
    end

    context "with a line of repeated hashes" do
      it "returns true" do
        expect(described_class.recognize?("###########")).to be true
      end
    end

    context "with the default border pattern" do
      it "returns true" do
        expect(described_class.recognize?(described_class::SEPARATOR)).to be true
      end
    end

    context "with mixed punctuation" do
      it "returns true" do
        expect(described_class.recognize?("---+---+---+---")).to be true
      end
    end

    context "with a short line" do
      it "returns false" do
        expect(described_class.recognize?("---")).to be false
      end
    end

    context "with alphanumeric content" do
      it "returns false" do
        expect(described_class.recognize?("hello world")).to be false
      end
    end

    context "with a BEGIN line" do
      it "returns false" do
        expect(described_class.recognize?('BEGIN "foo.rb"')).to be false
      end
    end

    context "with an END line" do
      it "returns false" do
        expect(described_class.recognize?('END "foo.rb"')).to be false
      end
    end

    context "with an empty string" do
      it "returns false" do
        expect(described_class.recognize?("")).to be false
      end
    end

    context "with whitespace-mangled border" do
      it "returns true" do
        expect(described_class.recognize?("---  ---  ---  ---")).to be true
      end
    end
  end

  describe ".strip_suffix" do
    context "with trailing border on content" do
      it "strips the border suffix" do
        expect(described_class.strip_suffix("puts 'hello'\n----------\n")).to eq("puts 'hello'")
      end
    end

    context "with no border suffix" do
      it "returns the text unchanged" do
        expect(described_class.strip_suffix("clean content\n")).to eq("clean content\n")
      end
    end
  end
end
