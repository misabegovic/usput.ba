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

  # Additional filter tests
  test "filters by has_audio true" do
    result = Platform::DSL.execute("locations { has_audio: true } | count")

    assert_kind_of Integer, result
  end

  test "filters by has_audio false" do
    result = Platform::DSL.execute("locations { has_audio: false } | count")

    assert_kind_of Integer, result
  end

  test "filters by missing_description true" do
    result = Platform::DSL.execute("locations { missing_description: true } | count")

    assert_kind_of Integer, result
  end

  test "filters by missing_description false" do
    result = Platform::DSL.execute("locations { missing_description: false } | count")

    assert_kind_of Integer, result
  end

  test "filters by ai_generated true" do
    result = Platform::DSL.execute("locations { ai_generated: true } | count")

    assert_kind_of Integer, result
  end

  test "filters by ai_generated false" do
    result = Platform::DSL.execute("locations { ai_generated: false } | count")

    assert_kind_of Integer, result
  end

  # Operation tests
  test "executes order by name asc" do
    result = Platform::DSL.execute("locations | order name asc | limit 5")

    assert_kind_of Array, result
  end

  test "executes sort by id" do
    result = Platform::DSL.execute("locations | sort id | limit 2")

    assert_kind_of Array, result
  end

  test "executes show operation" do
    result = Platform::DSL.execute("locations | show")

    assert_kind_of Array, result
    assert result.first.key?(:id)
  end

  test "raises error for unknown operation" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_operation, Location.all, { name: :unknown_op })
    end
  end

  # Aggregate tests
  test "aggregate sum" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Review.all, {
      args: ["sum", :rating],
      group_by: nil
    })

    # Sum may be nil or number
    assert result.nil? || result.is_a?(Numeric)
  end

  test "aggregate avg" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Review.all, {
      args: ["avg", :rating],
      group_by: nil
    })

    assert result.nil? || result.is_a?(Numeric)
  end

  test "aggregate avg with group_by" do
    result = Platform::DSL::Executor.send(:apply_aggregate, Location.all, {
      args: ["count"],
      group_by: :city
    })

    assert_kind_of Hash, result
  end

  test "raises error for unknown aggregate function" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_aggregate, Location.all, {
        args: ["unknown_func"],
        group_by: nil
      })
    end
  end

  # Format record tests
  test "format_record for Location" do
    result = Platform::DSL::Executor.send(:format_record, @sarajevo_location)

    assert_equal @sarajevo_location.id, result[:id]
    assert_equal @sarajevo_location.name, result[:name]
    assert_equal @sarajevo_location.city, result[:city]
  end

  test "format_record for Experience" do
    experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 60
    )

    result = Platform::DSL::Executor.send(:format_record, experience)

    assert_equal experience.id, result[:id]
    assert_equal "Test Experience", result[:title]
  end

  test "format_record for Plan" do
    plan = Plan.create!(title: "Test Plan")

    result = Platform::DSL::Executor.send(:format_record, plan)

    assert_equal plan.id, result[:id]
    assert_equal "Test Plan", result[:title]
  end

  test "format_record for User" do
    user = User.create!(username: "testuser_#{SecureRandom.hex(4)}", password: "password123")

    result = Platform::DSL::Executor.send(:format_record, user)

    assert_equal user.id, result[:id]
    assert_equal user.username, result[:username]
  end

  test "format_record for unknown model" do
    # Use a simple object with attributes method
    record = Object.new
    record.define_singleton_method(:attributes) { { "id" => 1, "name" => "Test", "other" => "value" } }

    result = Platform::DSL::Executor.send(:format_record, record)

    assert_equal 1, result["id"]
    assert_equal "Test", result["name"]
  end

  # Check methods tests
  test "check_api_keys returns status for each key" do
    result = Platform::DSL::Executor.send(:check_api_keys)

    assert result.key?(:anthropic)
    assert result.key?(:geoapify)
    assert result.key?(:elevenlabs)
  end

  test "check_database_health returns ok" do
    result = Platform::DSL::Executor.send(:check_database_health)

    assert_equal "ok", result[:status]
  end

  test "check_storage_health returns service name" do
    result = Platform::DSL::Executor.send(:check_storage_health)

    assert result.key?(:service) || result.key?(:status)
  end

  # Cached stats tests
  test "build_stats returns directly when no cache" do
    PlatformStatistic.where(key: "layer_zero").delete_all

    result = Platform::DSL::Executor.send(:build_stats)

    assert_equal :live, result[:source]
  end

  test "format_cached_stats formats data correctly" do
    data = {
      "stats" => { "locations" => 100, "users" => 50, "curators" => 5 },
      "by_city" => { "Sarajevo" => 30 },
      "coverage" => { "cities" => 10 },
      "computed_at" => "2024-01-01T00:00:00Z"
    }

    result = Platform::DSL::Executor.send(:format_cached_stats, data)

    assert_equal :cached, result[:source]
    assert_equal 100, result[:content]["locations"]
    assert_equal 50, result[:users][:total]
  end

  test "format_cached_stats handles symbol keys" do
    data = {
      stats: { locations: 100, users: 50, curators: 5 },
      by_city: { "Sarajevo" => 30 },
      coverage: { cities: 10 },
      computed_at: "2024-01-01T00:00:00Z"
    }

    result = Platform::DSL::Executor.send(:format_cached_stats, data)

    assert_equal :cached, result[:source]
  end

  # Apply filter edge cases
  test "apply_filter with array value" do
    scope = Platform::DSL::Executor.send(:apply_filter, Location.all, :city, ["Sarajevo", "Mostar"])

    assert scope.to_sql.include?("IN")
  end

  test "apply_filter raises for unknown column" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:apply_filter, Location.all, :nonexistent_column, "value")
    end
  end

  # Table queries
  test "executes users query" do
    result = Platform::DSL.execute("users | count")

    assert_kind_of Integer, result
  end

  test "executes reviews query" do
    result = Platform::DSL.execute("reviews | count")

    assert_kind_of Integer, result
  end

  # Where condition tests
  test "apply_where_condition with greater than" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id > 0")

    assert scope.to_sql.include?(">")
  end

  test "apply_where_condition with less than" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id < 999999")

    assert scope.to_sql.include?("<")
  end

  test "apply_where_condition with equal" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "id = 1")

    # Just verify it doesn't raise
    assert scope.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with invalid condition returns scope" do
    scope = Platform::DSL::Executor.send(:apply_where_condition, Location.all, "invalid condition")

    assert_equal Location.all.to_sql, scope.to_sql
  end

  # Apply operations with nil
  test "apply_operations with nil returns limited records" do
    result = Platform::DSL::Executor.send(:apply_operations, Location.all, nil)

    assert result.length <= 100
  end

  test "apply_operations with empty array returns limited records" do
    result = Platform::DSL::Executor.send(:apply_operations, Location.all, [])

    assert result.length <= 100
  end
end
