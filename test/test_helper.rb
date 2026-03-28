require "minitest/reporters"
require "minitest/mock"
require "minitest/autorun"
require "tmpdir"
require "pathname"
require_relative "../lib/codeball"

Minitest::Reporters.use!

module BundleTestHelper
  def build_bundle(*files)
    files.map do |path, contents|
      "#{@border}\n" \
      "BEGIN #{path.inspect}\n" \
      "#{@border}\n" \
      "#{contents}" \
      "#{@border}\n" \
      "END #{path.inspect}\n" \
      "#{@border}\n"
    end.join("\n")
  end
end
