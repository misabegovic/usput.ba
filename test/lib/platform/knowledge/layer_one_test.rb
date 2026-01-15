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
end
