require "delegate"

module Codeball
  # A file path extracted from a BEGIN marker in a codeball.
  #
  # String wrapper providing identity for pattern matching.
  #
  class Header < SimpleDelegator; end
end
