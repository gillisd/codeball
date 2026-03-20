require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_default_config_values
    config = Codeball::Config.default

    assert_equal "---\t", config.border
    assert_equal 10, config.border_width
    assert_equal ".", config.output_dir
    refute_predicate config, :dry_run
  end

  def test_full_border_repeats_border_pattern
    config = Codeball::Config.new(border: "ab", border_width: 3, output_dir: ".", dry_run: false)

    assert_equal "ababab", config.full_border
  end

  def test_terminator_is_last_character_of_border
    config = Codeball::Config.new(border: "---\t", border_width: 1, output_dir: ".", dry_run: false)
    assert_equal "\t", config.terminator

    config = Codeball::Config.new(border: "###", border_width: 1, output_dir: ".", dry_run: false)
    assert_equal "#", config.terminator
  end
end
