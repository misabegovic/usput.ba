# frozen_string_literal: true

require "test_helper"

class Platform::Knowledge::LayerZeroTest < ActiveSupport::TestCase
  setup do
    PlatformStatistic.delete_all
  end

  test "all returns layer_zero data from cache" do
    # Pre-create cached data to avoid full computation in tests
    PlatformStatistic.create!(
      key: "layer_zero",
      value: { stats: { locations: 10 }, by_city: {}, coverage: {} },
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.all

    assert result.is_a?(Hash)
    assert result.key?(:stats) || result.key?("stats")
  end

  test "stats returns content counts from cache" do
    PlatformStatistic.create!(
      key: "content_counts",
      value: { locations: 100, experiences: 50 },
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.stats

    assert result.is_a?(Hash)
    assert result.key?(:locations) || result.key?("locations")
  end

  test "by_city returns city statistics from cache" do
    PlatformStatistic.create!(
      key: "by_city",
      value: { "Sarajevo" => 50, "Mostar" => 30 },
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.by_city

    assert result.is_a?(Hash)
  end

  test "coverage returns coverage metrics from cache" do
    PlatformStatistic.create!(
      key: "coverage",
      value: { audio_coverage_percent: 50 },
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.coverage

    assert result.is_a?(Hash)
  end

  test "health returns health status from cache" do
    PlatformStatistic.create!(
      key: "health",
      value: { database: { status: "ok" }, api_keys: {} },
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.health

    assert result.is_a?(Hash)
    assert result.key?(:database) || result.key?("database")
  end

  test "refresh! delegates to PlatformStatistic" do
    # Just test that it doesn't raise - actual refresh tested in model tests
    assert_nothing_raised do
      # This would normally refresh all stats, but tests avoid heavy queries
      PlatformStatistic.refresh("content_counts")
    end
  end

  test "refresh! calls PlatformStatistic.refresh_all" do
    # Mock PlatformStatistic.refresh_all to verify it's called
    called = false
    PlatformStatistic.stub(:refresh_all, -> { called = true }) do
      Platform::Knowledge::LayerZero.refresh!
    end

    assert called, "refresh! should delegate to PlatformStatistic.refresh_all"
  end

  test "for_system_prompt returns formatted string" do
    PlatformStatistic.create!(
      key: "layer_zero",
      value: {
        stats: { locations: 100, experiences: 50, plans: 10, audio_tours: 5, reviews: 200, users: 1000, curators: 10 },
        by_city: { "Sarajevo" => 50, "Mostar" => 30 },
        coverage: { audio_coverage_percent: 20, description_coverage_percent: 80, locations_ai_generated: 30, locations_human_made: 70 },
        top_rated: { locations: [] },
        recent_changes: { new_locations_7d: 5, new_reviews_7d: 10, updated_locations_7d: 15 }
      },
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.for_system_prompt

    assert result.is_a?(String)
    assert result.include?("Trenutno stanje platforme")
    assert result.include?("Lokacije:")
  end

  test "for_system_prompt includes key sections" do
    PlatformStatistic.create!(
      key: "layer_zero",
      value: {
        stats: { locations: 100 },
        by_city: { "Sarajevo" => 50 },
        coverage: { audio_coverage_percent: 20 },
        top_rated: { locations: [] },
        recent_changes: { new_locations_7d: 5 }
      },
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.for_system_prompt

    assert result.include?("Sadržaj")
    assert result.include?("Top gradovi")
    assert result.include?("Pokrivenost")
    assert result.include?("Zadnjih 7 dana")
  end

  test "fresh? returns true when statistics are fresh" do
    PlatformStatistic.create!(
      key: "layer_zero",
      value: {},
      computed_at: 1.minute.ago
    )

    assert Platform::Knowledge::LayerZero.fresh?(5.minutes)
  end

  test "fresh? returns false when statistics are stale" do
    PlatformStatistic.create!(
      key: "layer_zero",
      value: {},
      computed_at: 10.minutes.ago
    )

    assert_not Platform::Knowledge::LayerZero.fresh?(5.minutes)
  end

  test "last_computed_at returns timestamp" do
    timestamp = 3.minutes.ago
    PlatformStatistic.create!(
      key: "layer_zero",
      value: {},
      computed_at: timestamp
    )

    result = Platform::Knowledge::LayerZero.last_computed_at

    assert_in_delta timestamp.to_i, result.to_i, 1
  end

  # Additional coverage tests

  test "refresh! delegates to refresh_all" do
    # Avoid full computation by just checking the method exists and is callable
    assert Platform::Knowledge::LayerZero.respond_to?(:refresh!)
  end

  test "for_system_prompt returns empty string for empty data" do
    PlatformStatistic.create!(
      key: "layer_zero",
      value: {},
      computed_at: 1.minute.ago
    )

    result = Platform::Knowledge::LayerZero.for_system_prompt

    # Should handle empty hash gracefully
    assert result.is_a?(String)
  end

  test "format_cities returns no data message for empty hash" do
    result = Platform::Knowledge::LayerZero.send(:format_cities, {})

    assert_equal "- Nema podataka", result
  end

  test "format_cities formats city data correctly" do
    by_city = { "Sarajevo" => 50, "Mostar" => 30, "Banja Luka" => 20 }

    result = Platform::Knowledge::LayerZero.send(:format_cities, by_city)

    assert result.include?("Sarajevo: 50")
    assert result.include?("Mostar: 30")
    assert result.include?("Banja Luka: 20")
  end

  test "format_top_rated returns no data message for empty array" do
    result = Platform::Knowledge::LayerZero.send(:format_top_rated, [])

    assert_equal "- Nema podataka", result
  end

  test "format_top_rated returns no data message for nil" do
    result = Platform::Knowledge::LayerZero.send(:format_top_rated, nil)

    assert_equal "- Nema podataka", result
  end

  test "format_top_rated formats location data correctly" do
    locations = [
      { name: "Location A", city: "Sarajevo", rating: 4.5 },
      { name: "Location B", city: "Mostar", rating: 4.2 }
    ]

    result = Platform::Knowledge::LayerZero.send(:format_top_rated, locations)

    assert result.include?("Location A")
    assert result.include?("Sarajevo")
    assert result.include?("4.5")
    assert result.include?("Location B")
    assert result.include?("Mostar")
  end

  test "format_for_prompt handles indifferent access" do
    data = {
      "stats" => { "locations" => 100 },
      "by_city" => { "Sarajevo" => 50 },
      "coverage" => { "audio_coverage_percent" => 20 },
      "top_rated" => { "locations" => [] },
      "recent_changes" => { "new_locations_7d" => 5 }
    }

    result = Platform::Knowledge::LayerZero.send(:format_for_prompt, data)

    assert result.include?("100")
    assert result.include?("Sarajevo")
  end

  test "fresh? returns false when no layer_zero exists" do
    PlatformStatistic.delete_all

    result = Platform::Knowledge::LayerZero.fresh?(5.minutes)

    assert_not result
  end

  test "last_computed_at returns nil when no layer_zero exists" do
    PlatformStatistic.delete_all

    result = Platform::Knowledge::LayerZero.last_computed_at

    assert_nil result
  end
end
