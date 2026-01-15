# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ParserTest < ActiveSupport::TestCase
  # Schema queries
  test "parses schema stats query" do
    ast = Platform::DSL::Parser.parse("schema | stats")
    assert_equal :schema_query, ast[:type]
    assert_equal :stats, ast[:operations].first[:name]
  end

  # Table queries
  test "parses simple table query" do
    ast = Platform::DSL::Parser.parse("locations | count")
    assert_equal :table_query, ast[:type]
    assert_equal "locations", ast[:table]
    assert_equal :count, ast[:operations].first[:name]
  end

  test "parses table query with string filter" do
    ast = Platform::DSL::Parser.parse('locations { city: "Mostar" } | count')
    assert_equal :table_query, ast[:type]
    assert_equal "locations", ast[:table]
    assert_equal "Mostar", ast[:filters][:city]
    assert_equal :count, ast[:operations].first[:name]
  end

  test "parses table query with multiple filters" do
    ast = Platform::DSL::Parser.parse('locations { city: "Sarajevo", type: "restaurant" } | sample 5')
    assert_equal :table_query, ast[:type]
    assert_equal "Sarajevo", ast[:filters][:city]
    assert_equal "restaurant", ast[:filters][:type]
  end

  test "parses table query with integer filter" do
    ast = Platform::DSL::Parser.parse("locations { id: 123 } | show")
    assert_equal :table_query, ast[:type]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses table query with boolean filter" do
    ast = Platform::DSL::Parser.parse("locations { has_audio: true } | count")
    assert_equal :table_query, ast[:type]
    assert_equal true, ast[:filters][:has_audio]
  end

  # Operations with arguments
  test "parses sample operation with argument" do
    ast = Platform::DSL::Parser.parse("locations | sample 10")
    assert_equal :sample, ast[:operations].first[:name]
    assert_includes ast[:operations].first[:args], 10
  end

  test "parses aggregate with group by" do
    ast = Platform::DSL::Parser.parse("locations | aggregate count() by city")
    op = ast[:operations].first
    assert_equal :aggregate, op[:name]
    assert_equal :city, op[:group_by]
  end

  # Error handling
  test "raises ParseError for invalid syntax" do
    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL::Parser.parse("invalid $$% syntax")
    end
  end
end
