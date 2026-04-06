require "codeball"

RSpec.describe Codeball::Footer do
  let(:footer) { described_class.new("hello.rb") }

  describe "delegation" do
    it "delegates to_s to the wrapped string" do
      expect(footer.to_s).to eq("hello.rb")
    end

    it "delegates == to the wrapped string" do
      expect(footer).to eq("hello.rb")
    end
  end
end
