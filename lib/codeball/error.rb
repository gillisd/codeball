module Codeball
  # Base error class for all Codeball-specific exceptions.
  class Error < StandardError; end

  # Raised when parsing a bundle that does not conform to the expected format.
  class MalformedBundleError < Error; end
end
