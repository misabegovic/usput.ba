# frozen_string_literal: true

require "test_helper"

class Platform::DSL::SummariesTest < ActiveSupport::TestCase
  setup do
    KnowledgeSummary.delete_all

    # Create test summary
    @summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "TestDSLCity",
      summary: "Test summary for DSL",
      stats: { total_locations: 10 },
      issues: [{ type: "missing_audio", count: 5 }],
      patterns: ["Test pattern"],
      source_count: 10,
      generated_at: Time.current
    )
  end

  test "parses summaries | list" do
    ast = Platform::DSL::Parser.parse("summaries | list")

    assert_equal :summaries_query, ast[:type]
    assert_equal :list, ast[:operations].first[:name]
  end

  test "parses summaries with filter" do
    ast = Platform::DSL::Parser.parse('summaries { city: "Mostar" } | show')

    assert_equal :summaries_query, ast[:type]
    assert_equal "Mostar", ast[:filters][:city]
    assert_equal :show, ast[:operations].first[:name]
  end

  test "executes summaries | list" do
    result = Platform::DSL.execute("summaries | list")

    assert result.is_a?(Hash)
    assert result.key?(:cities)
    assert result.key?(:total)
  end

  test "executes summaries with city filter | show" do
    result = Platform::DSL.execute('summaries { city: "TestDSLCity" } | show')

    assert result.is_a?(Hash)
    assert_equal "city", result[:dimension]
    assert_equal "TestDSLCity", result[:value]
    assert result[:summary].present?
  end

  test "executes summaries with city filter | issues" do
    result = Platform::DSL.execute('summaries { city: "TestDSLCity" } | issues')

    assert result.is_a?(Array)
    assert result.any? { |i| i["type"] == "missing_audio" || i[:type] == "missing_audio" }
  end

  test "raises error for show without filter" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("summaries | show")
    end
  end

  test "raises error for unknown operation" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("summaries | unknown_op")
    end
  end

  # Additional coverage tests

  test "executes summaries | issues for all issues" do
    result = Platform::DSL.execute("summaries | issues")

    assert result.is_a?(Array)
  end

  test "executes summaries with dimension filter | list" do
    result = Platform::DSL.execute('summaries { dimension: "city" } | list')

    assert result.is_a?(Array)
  end

  test "executes summaries | refresh" do
    result = Platform::DSL.execute('summaries { city: "TestDSLCity" } | refresh')

    assert result.is_a?(String)
    assert result.include?("Refresh")
  end

  test "executes summaries refresh all for dimension" do
    result = Platform::DSL.execute('summaries { dimension: "city" } | refresh')

    assert result.is_a?(String)
  end

  test "executes summaries refresh all" do
    result = Platform::DSL.execute("summaries | refresh")

    assert result.is_a?(String)
    assert result.include?("Queued")
  end

  test "show_issues returns empty for non-existent summary" do
    result = Platform::DSL.execute('summaries { city: "NonExistentCity" } | issues')

    assert_equal [], result
  end

  test "extract_dimension_and_value with category" do
    result = Platform::DSL::Executor.send(:extract_dimension_and_value, { category: "Restaurant" })

    assert_equal ["category", "Restaurant"], result
  end

  test "extract_dimension_and_value with region" do
    result = Platform::DSL::Executor.send(:extract_dimension_and_value, { region: "Herzegovina" })

    assert_equal ["region", "Herzegovina"], result
  end

  test "extract_dimension_and_value with dimension and value" do
    result = Platform::DSL::Executor.send(:extract_dimension_and_value, { dimension: "custom", value: "val" })

    assert_equal ["custom", "val"], result
  end

  test "extract_dimension_and_value with no filters" do
    result = Platform::DSL::Executor.send(:extract_dimension_and_value, {})

    assert_equal [nil, nil], result
  end
end
