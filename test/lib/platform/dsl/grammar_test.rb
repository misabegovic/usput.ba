# frozen_string_literal: true

require "test_helper"

class Platform::DSL::GrammarTest < ActiveSupport::TestCase
  setup do
    @grammar = Platform::DSL::Grammar.new
  end

  # Schema queries
  test "parses schema | stats" do
    result = @grammar.parse("schema | stats")
    assert result
  end

  test "parses schema | describe locations" do
    result = @grammar.parse("schema | describe locations")
    assert result
  end

  test "parses schema | health" do
    result = @grammar.parse("schema | health")
    assert result
  end

  # Table queries with filters
  test "parses table query with string filter" do
    result = @grammar.parse('locations { city: "Mostar" }')
    assert result
    # Just verify parsing succeeds - detailed structure tested in parser_test
  end

  test "parses table query with multiple filters" do
    result = @grammar.parse('locations { city: "Mostar", type: "restaurant" }')
    assert result
  end

  test "parses table query with integer filter" do
    result = @grammar.parse("locations { limit: 10 }")
    assert result
  end

  test "parses table query with boolean filter" do
    result = @grammar.parse("locations { has_audio: true }")
    assert result
  end

  # Operations
  test "parses count operation" do
    result = @grammar.parse("locations | count")
    assert result
  end

  test "parses sample operation with argument" do
    result = @grammar.parse("locations | sample 10")
    assert result
  end

  test "parses limit operation" do
    result = @grammar.parse("locations | limit 20")
    assert result
  end

  test "parses aggregate with group by" do
    result = @grammar.parse("locations | aggregate count() by city")
    assert result
  end

  # Combined queries
  test "parses full query with filters and operations" do
    result = @grammar.parse('locations { city: "Sarajevo" } | sample 5')
    assert result
  end

  test "parses query with multiple operations" do
    result = @grammar.parse("locations | sort name asc | limit 10")
    assert result
  end

  # Whitespace handling
  test "handles leading and trailing whitespace" do
    result = @grammar.parse("  locations | count  ")
    assert result
  end

  # Quality commands
  test "parses quality | stats" do
    result = @grammar.parse("quality | stats")
    assert result
  end

  test "parses quality | audit" do
    result = @grammar.parse("quality | audit")
    assert result
  end

  test "parses quality | locations" do
    result = @grammar.parse("quality | locations")
    assert result
  end

  test "parses quality | experiences" do
    result = @grammar.parse("quality | experiences")
    assert result
  end

  test "parses quality with filters" do
    result = @grammar.parse("quality { limit: 10 } | locations")
    assert result
  end

  # Invalid queries
  test "raises on invalid syntax" do
    assert_raises(Parslet::ParseFailed) do
      @grammar.parse("invalid query syntax $$%")
    end
  end
end
