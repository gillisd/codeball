module Codeball
  # Assembles Entry objects from a stream of tokens produced by Cursor.
  #
  # Stream pulls tokens one at a time, feeds them to the current Entry,
  # and emits it when Entry reports valid or errored. Stream does not
  # know the Header -> Body -> Footer rules -- Entry enforces those
  # through its write-once setters.
  #
  # Nothing is discarded. Every entry -- valid, errored, or truncated
  # -- is emitted so the consumer can decide what to do with it.
  #
  class Stream
    include Enumerable

    def initialize(cursor:)
      @cursor = cursor
      new_entry
    end

    def each(&block)
      return enum_for(:each) unless block

      consume_tokens(&block)
      emit_incomplete(&block)
    end

    alias each_entry each

    private

    attr_reader :cursor

    def consume_tokens
      while (item = cursor.next_item) != Cursor::EOF
        feed(item)

        if @current_entry.valid? || @current_entry.errors?
          yield @current_entry
          new_entry
        end
      end
    end

    def emit_incomplete
      yield @current_entry if @current_entry&.incomplete? && @current_entry.header
    end

    def new_entry
      @current_entry = Entry.new
    end

    def feed(item)
      case item
      in Header => header then @current_entry.header = header
      in Body => body then @current_entry.body = body
      in Footer => footer then @current_entry.footer = footer
      end
    end
  end
end
