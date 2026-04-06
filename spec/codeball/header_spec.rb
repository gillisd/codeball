require "codeball"

RSpec.describe Codeball::Header do
  let(:header) { described_class.new("hello.rb") }

  describe "delegation" do
    it "delegates to_s to the wrapped string" do
      expect(header.to_s).to eq("hello.rb")
    end

    it "delegates == to the wrapped string" do
      expect(header).to eq("hello.rb")
    end
  end

  describe "pattern matching" do
    it "matches in Header in a case expression" do
      matched = case header
                in Codeball::Header then true
                else false
                end
      expect(matched).to be true
    end

    it "does not match in Body or in Footer" do
      expect(header).not_to be_a(Codeball::Body)
      expect(header).not_to be_a(Codeball::Footer)
    end
  end
end
