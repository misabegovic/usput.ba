# frozen_string_literal: true

require "test_helper"

class Platform::Knowledge::LayerOneTest < ActiveSupport::TestCase
  setup do
    KnowledgeSummary.delete_all

    # Create test location
    @location = Location.create!(
      name: "Test Location",
      city: "TestCity",
      lat: 43.8,
      lng: 18.4
    )
  end

  test "get_summary returns cached summary when fresh" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "TestCity",
      summary: "Cached summary",
      source_count: 10,
      generated_at: 10.minutes.ago
    )

    result = Platform::Knowledge::LayerOne.get_summary(:city, "TestCity", max_age: 1.hour)

    assert_equal summary.id, result.id
    assert_equal "Cached summary", result.summary
  end

  test "get_summary generates new summary when stale" do
    KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "TestCity",
      summary: "Old summary",
      source_count: 5,
      generated_at: 2.hours.ago
    )

    result = Platform::Knowledge::LayerOne.get_summary(:city, "TestCity", max_age: 1.hour)

    # Should have refreshed
    assert result.generated_at > 1.hour.ago
  end

  test "generate_summary creates city summary" do
    result = Platform::Knowledge::LayerOne.generate_summary(:city, "TestCity")

    assert_not_nil result
    assert_equal "city", result.dimension
    assert_equal "TestCity", result.dimension_value
    assert result.source_count >= 1
    assert result.stats.present?
  end

  test "generate_summary returns nil for empty city" do
    result = Platform::Knowledge::LayerOne.generate_summary(:city, "NonExistentCity")

    assert_nil result
  end

  test "list_summaries returns summaries for dimension" do
    KnowledgeSummary.create!(dimension: "city", dimension_value: "A")
    KnowledgeSummary.create!(dimension: "city", dimension_value: "B")
    KnowledgeSummary.create!(dimension: "category", dimension_value: "C")

    result = Platform::Knowledge::LayerOne.list_summaries(:city)

    assert_equal 2, result.count
    assert result.all? { |s| s.dimension == "city" }
  end

  test "summaries_with_issues returns only summaries with issues" do
    with_issues = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "A",
      issues: [{ type: "test" }],
      generated_at: Time.current
    )
    KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "B",
      issues: [],
      generated_at: Time.current
    )

    result = Platform::Knowledge::LayerOne.summaries_with_issues

    assert_includes result, with_issues
    assert_equal 1, result.count
  end

  test "available_dimensions returns hash of dimensions and values" do
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Sarajevo")
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Mostar")
    KnowledgeSummary.create!(dimension: "category", dimension_value: "restaurant")

    result = Platform::Knowledge::LayerOne.available_dimensions

    assert result.key?("city")
    assert result.key?("category")
    assert_includes result["city"], "Sarajevo"
    assert_includes result["city"], "Mostar"
    assert_includes result["category"], "restaurant"
  end

  test "generate_summary identifies issues" do
    # Create location without description (different coordinates)
    Location.create!(
      name: "No Desc Location",
      city: "TestCity",
      lat: 43.9,
      lng: 18.5,
      description: nil
    )

    result = Platform::Knowledge::LayerOne.generate_summary(:city, "TestCity")

    # Should identify missing audio (no locations have audio in test)
    assert result.issues.any? { |i| i["type"] == "missing_audio" || i[:type] == "missing_audio" }
  end

  test "generate_summary detects patterns" do
    result = Platform::Knowledge::LayerOne.generate_summary(:city, "TestCity")

    # Patterns might be empty or have content depending on data
    assert result.patterns.is_a?(Array)
  end

  # Additional coverage tests

  test "generate_summary raises error for unknown dimension" do
    assert_raises(ArgumentError) do
      Platform::Knowledge::LayerOne.generate_summary(:unknown_dimension, "Value")
    end
  end

  test "generate_summary handles region dimension" do
    # Region is aliased to city for now
    result = Platform::Knowledge::LayerOne.generate_summary(:region, "TestCity")

    assert_not_nil result
    # Since it's aliased to city, dimension is "city"
    assert_equal "city", result.dimension
  end

  test "generate_category_summary returns nil for empty category" do
    result = Platform::Knowledge::LayerOne.generate_summary(:category, "nonexistent_category")

    assert_nil result
  end

  test "generate_category_summary creates summary for valid category" do
    # Create a category and assign our location to it
    category = LocationCategory.find_or_create_by!(key: "test_category", name: "Test Category")
    LocationCategoryAssignment.create!(location: @location, location_category: category)

    result = Platform::Knowledge::LayerOne.generate_summary(:category, "test_category")

    assert_not_nil result
    assert_equal "category", result.dimension
    assert_equal "test_category", result.dimension_value
  end

  test "detect_patterns identifies AI generated pattern" do
    # Create mostly AI-generated locations
    5.times do |i|
      Location.create!(
        name: "AI Location #{i}",
        city: "AICity",
        lat: 43.0 + i * 0.01,
        lng: 18.0 + i * 0.01,
        ai_generated: true
      )
    end

    result = Platform::Knowledge::LayerOne.generate_summary(:city, "AICity")

    assert result.patterns.include?("Većina sadržaja je AI generisana")
  end

  test "detect_patterns identifies audio coverage patterns" do
    result = Platform::Knowledge::LayerOne.generate_summary(:city, "TestCity")

    # Low audio coverage since test location has no audio
    assert result.patterns.any? { |p| p.include?("audio pokrivenost") }
  end

  test "detect_patterns for category identifies single city pattern" do
    # Our test location is in TestCity, so all locations will be in one city
    category = LocationCategory.find_or_create_by!(key: "single_city_cat", name: "Single City")
    LocationCategoryAssignment.create!(location: @location, location_category: category)

    result = Platform::Knowledge::LayerOne.generate_summary(:category, "single_city_cat")

    assert result.patterns.include?("Sve lokacije su u jednom gradu")
  end

  test "collect_city_stats returns comprehensive statistics" do
    stats = Platform::Knowledge::LayerOne.send(:collect_city_stats, "TestCity", Location.where(city: "TestCity"))

    assert stats[:total_locations] >= 1
    assert stats.key?(:with_audio)
    assert stats.key?(:with_description)
    assert stats.key?(:ai_generated)
    assert stats.key?(:human_made)
    assert stats.key?(:avg_rating)
    assert stats.key?(:by_type)
    assert stats.key?(:audio_coverage)
    assert stats.key?(:description_coverage)
  end

  test "collect_category_stats returns comprehensive statistics" do
    category = LocationCategory.find_or_create_by!(key: "stats_test", name: "Stats Test")
    LocationCategoryAssignment.create!(location: @location, location_category: category)

    locations = Location.joins(:location_categories).where(location_categories: { key: "stats_test" })
    stats = Platform::Knowledge::LayerOne.send(:collect_category_stats, "stats_test", locations)

    assert stats[:total_locations] >= 1
    assert stats.key?(:with_audio)
    assert stats.key?(:by_city)
    assert stats.key?(:avg_rating)
  end

  test "identify_city_issues detects short descriptions" do
    # Create location with short description
    Location.create!(
      name: "Short Desc",
      city: "ShortCity",
      lat: 43.5,
      lng: 18.5,
      description: "Short"
    )

    locations = Location.where(city: "ShortCity")
    stats = Platform::Knowledge::LayerOne.send(:collect_city_stats, "ShortCity", locations)
    issues = Platform::Knowledge::LayerOne.send(:identify_city_issues, "ShortCity", locations, stats)

    assert issues.any? { |i| i[:type] == "short_description" }
  end

  test "identify_city_issues detects low audio coverage" do
    locations = Location.where(city: "TestCity")
    stats = Platform::Knowledge::LayerOne.send(:collect_city_stats, "TestCity", locations)
    issues = Platform::Knowledge::LayerOne.send(:identify_city_issues, "TestCity", locations, stats)

    assert issues.any? { |i| i[:type] == "low_audio_coverage" }
  end

  test "format_location_for_ai returns correct format" do
    result = Platform::Knowledge::LayerOne.send(:format_location_for_ai, @location)

    assert_equal @location.name, result[:name]
    assert_equal @location.city, result[:city]
    assert result.key?(:description)
    assert result.key?(:has_audio)
    assert result.key?(:rating)
    assert result.key?(:categories)
  end

  test "generate_fallback_summary for city" do
    stats = { total_locations: 10, audio_coverage: 50, avg_rating: 4.0 }
    issues = [{ type: "missing_audio", count: 5 }]

    result = Platform::Knowledge::LayerOne.send(:generate_fallback_summary, :city, "TestCity", stats, issues)

    assert result.include?("TestCity")
    assert result.include?("10 lokacija")
    assert result.include?("50%")
  end

  test "generate_fallback_summary for category" do
    stats = { total_locations: 20, audio_coverage: 30, by_city: { "A" => 10, "B" => 10 } }
    issues = []

    result = Platform::Knowledge::LayerOne.send(:generate_fallback_summary, :category, "test_cat", stats, issues)

    assert result.include?("Kategorija")
    assert result.include?("20 lokacija")
    assert result.include?("2 gradova")
  end

  test "generate_fallback_summary for unknown dimension" do
    stats = { total_locations: 5 }
    issues = []

    result = Platform::Knowledge::LayerOne.send(:generate_fallback_summary, :other, "other", stats, issues)

    assert result.include?("Summary za")
    assert result.include?("5 stavki")
  end

  test "build_summary_prompt includes all sections" do
    stats = { total: 10 }
    sample_data = [{ name: "Test", city: "City", description: "Desc" }]
    issues = [{ type: "test_issue", count: 5 }]

    result = Platform::Knowledge::LayerOne.send(:build_summary_prompt, :city, "TestCity", stats, sample_data, issues)

    assert result.include?("city")
    assert result.include?("TestCity")
    assert result.include?("Statistike")
    assert result.include?("Uzorak lokacija")
    assert result.include?("Test")
    assert result.include?("test_issue")
  end

  test "refresh_dimension refreshes city summaries" do
    # Create a city with location
    # Just verify it doesn't raise
    assert_nothing_raised do
      Platform::Knowledge::LayerOne.refresh_dimension(:city)
    end
  end
end
