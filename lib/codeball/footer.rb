require "delegate"

module Codeball
  # A file path extracted from an END marker in a codeball.
  #
  # String wrapper providing identity for pattern matching.
  #
  class Footer < SimpleDelegator; end
end
