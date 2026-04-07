require "command_kit/open"

module CommandKit
  # Opens readable arguments as IO streams, defaulting to stdin.
  # Uses <tt>CommandKit::Open#open</tt> to handle filenames and +"-"+ for stdin.
  module CombinedIO
    include CommandKit::Open

    def self.included(base)
      base.prepend Prepended
    end

    # Prepends +run+ to open file arguments (or stdin) as IO streams.
    module Prepended
      def run(*args)
        args << "-" if args.empty?

        ios = args.map { |readable| self.open(readable) }

        begin
          super(*ios)
        ensure
          ios.each(&:close)
        end
      end
    end
  end
end
