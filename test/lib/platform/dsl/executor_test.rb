# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ExecutorTest < ActiveSupport::TestCase
  setup do
    # Create test locations - will be rolled back automatically by Rails test transactions
    @sarajevo_location = Location.create!(
      name: "Test Location Sarajevo",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )
    @mostar_location = Location.create!(
      name: "Test Location Mostar",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078
    )
  end

  # No teardown needed - Rails transactions handle cleanup

  # Schema queries
  test "executes schema stats" do
    result = Platform::DSL.execute("schema | stats")

    assert_kind_of Hash, result
    assert result[:content].key?(:locations)
    assert result[:content].key?(:experiences)
    assert result.key?(:by_city)
    assert result.key?(:coverage)
    assert result.key?(:users)
  end

  test "executes schema describe" do
    result = Platform::DSL.execute("schema | describe locations")

    assert_equal "locations", result[:table].to_s
    assert_includes result[:columns], "name"
    assert_includes result[:columns], "city"
    assert result[:count] >= 2
  end

  test "executes schema health" do
    result = Platform::DSL.execute("schema | health")

    assert_kind_of Hash, result
    assert result.key?(:database)
    assert result.key?(:api_keys)
  end

  # Table queries
  test "executes count query" do
    result = Platform::DSL.execute("locations | count")

    assert_kind_of Integer, result
    assert result >= 2
  end

  test "executes count with filter" do
    result = Platform::DSL.execute('locations { city: "Sarajevo" } | count')

    assert_kind_of Integer, result
    assert result >= 1
  end

  test "executes sample query" do
    result = Platform::DSL.execute("locations | sample 2")

    assert_kind_of Array, result
    assert result.length <= 2
    assert result.first.key?(:id)
    assert result.first.key?(:name)
    assert result.first.key?(:city)
  end

  test "executes limit query" do
    result = Platform::DSL.execute("locations | limit 1")

    assert_kind_of Array, result
    assert_equal 1, result.length
  end

  test "executes aggregate count by city" do
    result = Platform::DSL.execute("locations | aggregate count() by city")

    assert_kind_of Hash, result
    assert result.key?("Sarajevo") || result.key?("Mostar")
  end

  # Filter variations
  test "filters by exact city match" do
    result = Platform::DSL.execute('locations { city: "Mostar" } | count')

    assert_kind_of Integer, result
    assert result >= 1
  end

  # Error handling
  test "raises ExecutionError for unknown table" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("unknown_table | count")
    end
  end

  test "raises ParseError for invalid DSL" do
    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL.execute("invalid $$$ query")
    end
  end
end
