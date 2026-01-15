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
end
