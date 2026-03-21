require "minitest/autorun"
require "minitest/mock" # minitest-mock gem — provides Object#stub
require "tmpdir"
require "pathname"

require_relative "../lib/codeball"

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
