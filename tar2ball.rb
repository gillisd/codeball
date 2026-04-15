require "zlib"
require_relative "lib/codeball"
require "rubygems/package"

gzipped_io = File.open("ball.tar.gz", "rb")
io = Zlib::GzipReader.wrap(gzipped_io)
tar_reader = Gem::Package::TarReader.new(io)
class LazyEntry
end

ball = tar_reader
       .lazy
       .map { |te|
  Codeball::Entry.new.tap { |ce|
    ce.name = te.header.name
    ce.body = te.read
  }
}
       .reject { it.body.empty? }
       .inject(Codeball::Ball.new) { |ball, entry| ball.tap { it.add_entry entry } }

binding.irb
puts ball.serialize
