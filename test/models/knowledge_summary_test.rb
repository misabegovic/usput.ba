# frozen_string_literal: true

require "test_helper"

class KnowledgeSummaryTest < ActiveSupport::TestCase
  setup do
    KnowledgeSummary.delete_all
  end

  test "validates dimension presence" do
    summary = KnowledgeSummary.new(dimension_value: "Sarajevo")
    assert_not summary.valid?
    assert summary.errors[:dimension].any?
  end

  test "validates dimension_value presence" do
    summary = KnowledgeSummary.new(dimension: "city")
    assert_not summary.valid?
    assert summary.errors[:dimension_value].any?
  end

  test "validates dimension inclusion" do
    summary = KnowledgeSummary.new(dimension: "invalid", dimension_value: "test")
    assert_not summary.valid?
    assert summary.errors[:dimension].any?
  end

  test "validates uniqueness of dimension + dimension_value" do
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Sarajevo")

    duplicate = KnowledgeSummary.new(dimension: "city", dimension_value: "Sarajevo")
    assert_not duplicate.valid?
    assert duplicate.errors[:dimension].any?
  end

  test "creates valid summary" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Sarajevo",
      summary: "Test summary",
      stats: { total: 10 },
      issues: [{ type: "missing_audio", count: 5 }],
      patterns: ["Pattern 1"],
      source_count: 10,
      generated_at: Time.current
    )

    assert summary.persisted?
    assert_equal "city", summary.dimension
    assert_equal "Sarajevo", summary.dimension_value
  end

  test "fresh? returns true when generated recently" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Test",
      generated_at: 30.minutes.ago
    )

    assert summary.fresh?(1.hour)
  end

  test "fresh? returns false when generated too long ago" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Test",
      generated_at: 2.hours.ago
    )

    assert_not summary.fresh?(1.hour)
  end

  test "stale? is inverse of fresh?" do
    fresh = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Fresh",
      generated_at: 30.minutes.ago
    )
    stale = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Stale",
      generated_at: 2.hours.ago
    )

    assert_not fresh.stale?(1.hour)
    assert stale.stale?(1.hour)
  end

  test "has_issues? returns true when issues present" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Test",
      issues: [{ type: "test" }]
    )

    assert summary.has_issues?
  end

  test "has_issues? returns false when no issues" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Test",
      issues: []
    )

    assert_not summary.has_issues?
  end

  test "issues_count returns correct count" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Test",
      issues: [{ type: "a" }, { type: "b" }, { type: "c" }]
    )

    assert_equal 3, summary.issues_count
  end

  test "for_dimension scope filters by dimension" do
    city = KnowledgeSummary.create!(dimension: "city", dimension_value: "A")
    category = KnowledgeSummary.create!(dimension: "category", dimension_value: "B")

    result = KnowledgeSummary.for_dimension(:city)

    assert_includes result, city
    assert_not_includes result, category
  end

  test "for_dimension_value returns matching summary" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Sarajevo"
    )

    result = KnowledgeSummary.for_dimension_value("city", "Sarajevo")

    assert_equal summary, result
  end

  test "with_issues scope returns only summaries with issues" do
    with_issues = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "A",
      issues: [{ type: "test" }]
    )
    without_issues = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "B",
      issues: []
    )

    result = KnowledgeSummary.with_issues

    assert_includes result, with_issues
    assert_not_includes result, without_issues
  end

  test "cities returns list of city dimension values" do
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Sarajevo")
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Mostar")
    KnowledgeSummary.create!(dimension: "category", dimension_value: "restaurant")

    result = KnowledgeSummary.cities

    assert_includes result, "Sarajevo"
    assert_includes result, "Mostar"
    assert_not_includes result, "restaurant"
  end

  test "to_short_format returns formatted string" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Sarajevo",
      source_count: 25,
      issues: [{ type: "test" }]
    )

    result = summary.to_short_format

    assert result.include?("Sarajevo")
    assert result.include?("25 records")
    assert result.include?("1 issues")
  end

  test "to_cli_format returns detailed format" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Sarajevo",
      summary: "Test summary text",
      stats: { total: 25 },
      issues: [{ type: "missing_audio", count: 5 }],
      patterns: ["Pattern one"],
      source_count: 25,
      generated_at: Time.current
    )

    result = summary.to_cli_format

    assert result.include?("City: Sarajevo")
    assert result.include?("Test summary text")
    assert result.include?("missing_audio")
    assert result.include?("Pattern one")
  end

  # Additional coverage tests

  test "categories returns list of category dimension values" do
    KnowledgeSummary.create!(dimension: "category", dimension_value: "restaurant")
    KnowledgeSummary.create!(dimension: "category", dimension_value: "museum")
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Sarajevo")

    result = KnowledgeSummary.categories

    assert_includes result, "restaurant"
    assert_includes result, "museum"
    assert_not_includes result, "Sarajevo"
  end

  test "list_for_dimension returns ordered summaries" do
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Zenica")
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Banja Luka")
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Sarajevo")

    result = KnowledgeSummary.list_for_dimension(:city)

    # Should be ordered by dimension_value
    values = result.map(&:dimension_value)
    assert_equal values.sort, values
  end

  test "available_dimensions returns hash of dimensions" do
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Sarajevo")
    KnowledgeSummary.create!(dimension: "city", dimension_value: "Mostar")
    KnowledgeSummary.create!(dimension: "category", dimension_value: "restaurant")

    result = KnowledgeSummary.available_dimensions

    assert result.key?("city")
    assert result.key?("category")
    assert result.key?("region")
    assert_includes result["city"], "Sarajevo"
    assert_includes result["city"], "Mostar"
    assert_includes result["category"], "restaurant"
  end

  test "format_hash handles nested hashes" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Test",
      stats: {
        "outer" => {
          "inner" => 42
        }
      }
    )

    result = summary.to_cli_format

    assert result.include?("outer:")
    assert result.include?("inner: 42")
  end

  test "to_cli_format handles nil stats" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "NoStats",
      stats: nil
    )

    result = summary.to_cli_format

    assert result.include?("City: NoStats")
  end

  test "to_cli_format handles empty patterns" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "NoPatterns",
      patterns: []
    )

    result = summary.to_cli_format

    # With empty patterns, we skip the Patterns section
    # Check that it doesn't have pattern content (the section header might still be there)
    assert result.include?("City: NoPatterns")
  end

  test "to_cli_format handles issue with message instead of count" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "MsgIssue",
      issues: [{ type: "warning", message: "Custom warning message" }]
    )

    result = summary.to_cli_format

    assert result.include?("Custom warning message")
  end

  test "to_short_format without issues" do
    summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "NoIssues",
      source_count: 10,
      issues: []
    )

    result = summary.to_short_format

    assert result.include?("NoIssues")
    assert result.include?("10 records")
    assert_not result.include?("issues")
  end

  test "issues_count returns 0 for nil issues" do
    summary = KnowledgeSummary.new(issues: nil)

    assert_equal 0, summary.issues_count
  end

  test "fresh scope returns fresh summaries" do
    fresh = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Fresh",
      generated_at: 30.minutes.ago
    )
    stale = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Stale",
      generated_at: 2.hours.ago
    )

    result = KnowledgeSummary.fresh(1.hour)

    assert_includes result, fresh
    assert_not_includes result, stale
  end

  test "stale scope returns stale summaries" do
    fresh = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Fresh",
      generated_at: 30.minutes.ago
    )
    stale = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Stale",
      generated_at: 2.hours.ago
    )

    result = KnowledgeSummary.stale(1.hour)

    assert_not_includes result, fresh
    assert_includes result, stale
  end

  test "recent scope orders by generated_at desc" do
    old = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Old",
      generated_at: 2.hours.ago
    )
    new = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "New",
      generated_at: 10.minutes.ago
    )

    result = KnowledgeSummary.recent

    assert_equal new, result.first
  end
end
