# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # Curator-entered urls are rendered as hrefs, and Rails does not escape the
  # scheme, so anything but absolute http(s) has to come back nil.
  test "safe_external_url passes absolute http and https through" do
    assert_equal "https://example.com/a?b=c", safe_external_url("https://example.com/a?b=c")
    assert_equal "http://example.com", safe_external_url("http://example.com")
    assert_equal "https://example.com", safe_external_url("  https://example.com  ")
  end

  test "safe_external_url refuses anything that is not absolute http(s)" do
    [
      "javascript:alert(1)",
      "JavaScript:alert(1)",
      "data:text/html,<script>alert(1)</script>",
      "vbscript:msgbox(1)",
      "//evil.example.com",
      "/relative/path",
      "example.com",
      "http://",
      "",
      nil
    ].each { |value| assert_nil safe_external_url(value), "#{value.inspect} must not become an href" }
  end

  test "returns the translated label for a season key" do
    assert_equal "Summer", experience_season_label("summer")
    assert_equal "Spring", experience_season_label("spring")
  end

  test "translates the season key per locale" do
    I18n.with_locale(:bs) do
      assert_equal "Ljeto", experience_season_label("summer")
    end
  end

  # A blank key would resolve to the parent node and return the whole
  # { all_year: ..., spring: ... } Hash, which renders as raw text on the page.
  test "falls back to all_year for a blank season instead of returning the parent hash" do
    [ nil, "", "  " ].each do |blank|
      label = experience_season_label(blank)

      assert_kind_of String, label
      assert_equal "All year", label
    end
  end

  test "humanizes an unknown season key" do
    assert_equal "Monsoon", experience_season_label("monsoon")
  end

  test "returns the translated label for a location category key" do
    assert_equal "Place", location_type_label("place")
  end

  test "falls back to place for a blank location category" do
    assert_kind_of String, location_type_label(nil)
    assert_equal location_type_label("place"), location_type_label(nil)
  end
end
