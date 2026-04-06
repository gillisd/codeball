require "codeball"

RSpec.describe Codeball::Body do
  describe "delegation" do
    let(:body) { described_class.new("puts 'hello'\n") }

    it "delegates to_s to the wrapped string" do
      expect(body.to_s).to eq("puts 'hello'\n")
    end

    it "delegates empty? to the wrapped string" do
      expect(body.empty?).to be false
    end
  end

  context "with empty content" do
    let(:body) { described_class.new("") }

    it "reports empty" do
      expect(body.empty?).to be true
    end
  end
end
