module Codeball
  # Configuration for bundle format and extraction behavior.
  #
  # ## Examples
  #
  # Using default configuration:
  #
  # ```ruby
  # config = Config.default
  # config.full_border  # => "---\t---\t---\t..." (repeated 10 times)
  # ```
  #
  # Custom border for markdown-heavy codebases:
  #
  # ```ruby
  # config = Config.new(border: "~~~", border_width: 5, output_dir: ".", dry_run: false)
  # ```
  #
  Config = Struct.new(:border, :border_width, :output_dir, :dry_run, keyword_init: true) do
    # The complete border string used to delimit sections in a bundle.
    # Returns the border pattern repeated `border_width` times.
    def full_border
      border * border_width
    end

    # The character used to ensure proper line termination.
    # Derived from the last character of the border pattern.
    def terminator
      border.chars.last
    end
  end

  Config::DEFAULTS = {
    border: "---\t",
    border_width: 10,
    output_dir: ".",
    dry_run: false
  }.freeze

  # Returns a new Config with sensible defaults.
  def Config.default
    new(**Config::DEFAULTS)
  end
end
