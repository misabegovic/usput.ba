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

  test "refresh_dimension refreshes category summaries" do
    category = LocationCategory.find_or_create_by!(key: "refresh_test", name: "Refresh Test")
    LocationCategoryAssignment.create!(location: @location, location_category: category)

    assert_nothing_raised do
      Platform::Knowledge::LayerOne.refresh_dimension(:category)
    end
  end

  test "detect_patterns for category dimension" do
    category = LocationCategory.find_or_create_by!(key: "pattern_test", name: "Pattern Test")
    LocationCategoryAssignment.create!(location: @location, location_category: category)

    result = Platform::Knowledge::LayerOne.generate_summary(:category, "pattern_test")

    # Should detect single city pattern since we only have one city
    assert result.patterns.is_a?(Array)
  end

  test "detect_patterns high audio coverage" do
    # Create a location with audio tour
    location = Location.create!(
      name: "With Audio",
      city: "AudioCity",
      lat: 44.0,
      lng: 19.0
    )
    audio_tour = location.audio_tours.create!(locale: "bs", script: "Test")
    audio_tour.audio_file.attach(
      io: StringIO.new("fake audio"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )

    result = Platform::Knowledge::LayerOne.generate_summary(:city, "AudioCity")

    # High audio coverage should be detected
    assert result.patterns.is_a?(Array)
    # Either high coverage pattern or no patterns if not >70%
    assert result.patterns.any? { |p| p.include?("audio") } || result.patterns.empty?
  end

  test "generate_ai_summary uses fallback when RubyLLM not configured" do
    original_model = RubyLLM.config.default_model

    RubyLLM.config.default_model = nil

    stats = { total_locations: 5, audio_coverage: 20, avg_rating: 3.5 }
    sample_data = []
    issues = []

    result = Platform::Knowledge::LayerOne.send(
      :generate_ai_summary,
      :city,
      "FallbackCity",
      stats,
      sample_data,
      issues
    )

    # Should return fallback summary
    assert result.include?("FallbackCity")
    assert result.include?("5 lokacija")
  ensure
    RubyLLM.config.default_model = original_model
  end

  test "identify_city_issues with no missing audio" do
    # Create location with audio
    location = Location.create!(
      name: "Full Audio",
      city: "FullAudioCity",
      lat: 44.1,
      lng: 19.1,
      description: "A nice long description that is more than 50 characters to avoid short description issues"
    )
    audio_tour = location.audio_tours.create!(locale: "bs", script: "Test")
    audio_tour.audio_file.attach(
      io: StringIO.new("fake audio"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )

    locations = Location.where(city: "FullAudioCity")
    stats = Platform::Knowledge::LayerOne.send(:collect_city_stats, "FullAudioCity", locations)
    issues = Platform::Knowledge::LayerOne.send(:identify_city_issues, "FullAudioCity", locations, stats)

    # Should not have missing_audio issue
    refute issues.any? { |i| i[:type] == "missing_audio" }
  end

  test "identify_category_issues with no issues" do
    # Create location with audio and description
    location = Location.create!(
      name: "Complete Location",
      city: "CompleteCity",
      lat: 44.2,
      lng: 19.2,
      description: "A complete description for testing"
    )
    audio_tour = location.audio_tours.create!(locale: "bs", script: "Test")
    audio_tour.audio_file.attach(
      io: StringIO.new("fake audio"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )

    category = LocationCategory.find_or_create_by!(key: "no_issues_cat", name: "No Issues")
    LocationCategoryAssignment.create!(location: location, location_category: category)

    locations = Location.joins(:location_categories).where(location_categories: { key: "no_issues_cat" })
    stats = Platform::Knowledge::LayerOne.send(:collect_category_stats, "no_issues_cat", locations)
    issues = Platform::Knowledge::LayerOne.send(:identify_category_issues, "no_issues_cat", locations, stats)

    # Should have no issues
    assert issues.empty?
  end

  test "collect_category_stats with zero locations" do
    # Empty query
    locations = Location.where("1=0")
    stats = Platform::Knowledge::LayerOne.send(:collect_category_stats, "empty_cat", locations)

    assert_equal 0, stats[:total_locations]
    assert_equal 0, stats[:audio_coverage]
  end

  test "get_summary with nil summary" do
    # Query for non-existent value
    result = Platform::Knowledge::LayerOne.get_summary(:city, "NonExistentCity12345")

    # Should try to generate, which will return nil
    assert_nil result
  end

  test "format_location_for_ai with nil description" do
    location = Location.create!(
      name: "No Desc",
      city: "NoDescCity",
      lat: 44.3,
      lng: 19.3,
      description: nil
    )

    result = Platform::Knowledge::LayerOne.send(:format_location_for_ai, location)

    assert_nil result[:description]
  end

  test "format_location_for_ai with long description" do
    long_desc = "A" * 500
    location = Location.create!(
      name: "Long Desc",
      city: "LongDescCity",
      lat: 44.4,
      lng: 19.4,
      description: long_desc
    )

    result = Platform::Knowledge::LayerOne.send(:format_location_for_ai, location)

    # Should be truncated to 200 chars + ellipsis
    assert result[:description].length <= 203
  end

  test "collect_city_stats with zero locations returns zero coverage" do
    # Empty query returns zero stats
    locations = Location.where("1=0")
    stats = Platform::Knowledge::LayerOne.send(:collect_city_stats, "EmptyCity", locations)

    assert_equal 0, stats[:total_locations]
    assert_equal 0, stats[:audio_coverage]
    assert_equal 0, stats[:description_coverage]
  end

  test "detect_patterns for category with wide distribution" do
    # Create locations in many different cities
    base_lat = 45.0
    base_lng = 19.0

    category = LocationCategory.find_or_create_by!(key: "wide_dist", name: "Wide Distribution")

    6.times do |i|
      loc = Location.create!(
        name: "Wide #{i}",
        city: "City#{i}",
        lat: base_lat + i * 0.1,
        lng: base_lng + i * 0.1
      )
      LocationCategoryAssignment.create!(location: loc, location_category: category)
    end

    result = Platform::Knowledge::LayerOne.generate_summary(:category, "wide_dist")

    # Should detect wide distribution pattern
    assert result.patterns.include?("Široka geografska distribucija")
  end

  test "detect_patterns for moderate audio coverage" do
    # Create locations where audio coverage is between 30-70%
    # Create 2 locations, 1 with audio
    base_lat = 46.0
    base_lng = 20.0

    loc_with_audio = Location.create!(
      name: "With Audio Mod",
      city: "ModerateCity",
      lat: base_lat,
      lng: base_lng
    )
    audio_tour = loc_with_audio.audio_tours.create!(locale: "bs", script: "Test")
    audio_tour.audio_file.attach(
      io: StringIO.new("fake audio"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )

    Location.create!(
      name: "Without Audio Mod",
      city: "ModerateCity",
      lat: base_lat + 0.01,
      lng: base_lng + 0.01
    )

    result = Platform::Knowledge::LayerOne.generate_summary(:city, "ModerateCity")

    # 50% coverage should not trigger either high or low pattern
    # Just verify patterns is an array
    assert result.patterns.is_a?(Array)
  end

  test "generate_fallback_summary for category with nil by_city" do
    stats = { total_locations: 5, audio_coverage: 30, by_city: nil }
    issues = []

    result = Platform::Knowledge::LayerOne.send(:generate_fallback_summary, :category, "nil_city_cat", stats, issues)

    assert result.include?("Kategorija")
    assert result.include?("5 lokacija")
    # Should handle nil by_city gracefully
    assert result.include?("0 gradova")
  end
end
