require "codeball"
require "ronin/support"
include Ronin::Support

tar = Archive::Tar::Reader.new(gzip_open("ball.tar.gz"))
tar
  .tap(&:rewind)
  .map { |tarentry|
  Codeball::Entry.new.tap {
    it.header = tarentry.header.name
    it.body = tarentry.read
  }
}
  .then { p it }
