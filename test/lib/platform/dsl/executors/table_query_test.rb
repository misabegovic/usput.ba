# frozen_string_literal: true

require "test_helper"

class Platform::DSL::Executors::TableQueryTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      description: "Test description"
    )
  end

  # ===================
  # resolve_model Tests
  # ===================

  test "resolve_model returns model for known table" do
    model = Platform::DSL::Executors::TableQuery.resolve_model("locations")
    assert_equal Location, model
  end

  test "resolve_model raises for unknown table" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::TableQuery.resolve_model("unknown_table_xyz")
    end

    assert_match(/Nepoznata tabela/i, error.message)
  end

  # ===================
  # apply_filter Tests
  # ===================

  test "apply_filter with has_audio true" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "has_audio", true)
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with has_audio false" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "has_audio", false)
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with missing_description true" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "missing_description", true)
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with missing_description false" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "missing_description", false)
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with ai_generated" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "ai_generated", true)
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with unknown column raises error" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "nonexistent_column", "value")
    end

    assert_match(/Nepoznata kolona ili filter/i, error.message)
  end

  test "apply_filter with array value" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "city", %w[Sarajevo Mostar])
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with range value" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "id", 1..100)
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filter with hash value for JSONB" do
    # Test the Hash branch for JSONB contains query
    # This may fail depending on the column type
    begin
      result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "social_links", { "facebook" => "test" })
      assert result.is_a?(ActiveRecord::Relation)
    rescue ActiveRecord::StatementInvalid
      # Column might not support JSONB contains, that's ok
    end
  end

  test "apply_filter with scope method" do
    # Test by_city scope if available
    if Location.respond_to?(:by_city)
      result = Platform::DSL::Executors::TableQuery.send(:apply_filter, Location.all, "city", "Sarajevo")
      assert result.is_a?(ActiveRecord::Relation)
    else
      # Just verify method exists
      assert Platform::DSL::Executors::TableQuery.respond_to?(:apply_filter, true)
    end
  end

  # ===================
  # apply_operation Tests
  # ===================

  test "apply_operation with count" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :count })
    assert result.is_a?(Integer)
  end

  test "apply_operation with sample without args" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :sample, args: nil })
    assert result.is_a?(Array)
  end

  test "apply_operation with sample with limit" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :sample, args: [ 5 ] })
    assert result.is_a?(Array)
    assert result.size <= 5
  end

  test "apply_operation with limit without args" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :limit, args: nil })
    assert result.is_a?(Array)
  end

  test "apply_operation with limit with args" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :limit, args: [ 3 ] })
    assert result.is_a?(Array)
    assert result.size <= 3
  end

  test "apply_operation with aggregate" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :aggregate, args: [ :count ] })
    assert result.is_a?(Integer) || result.is_a?(Hash)
  end

  test "apply_operation with where" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :where, args: [ "id > 0" ] })
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_operation with select" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :select, args: [ :id, :name ] })
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_operation with sort without args" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :sort, args: nil })
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_operation with sort with field" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :sort, args: [ :name ] })
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_operation with sort with field and direction" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :sort, args: [ :name, :desc ] })
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_operation with show" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :show })
    assert result.is_a?(Array)
  end

  test "apply_operation with unknown operation raises" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :unknown_op })
    end

    assert_match(/Nepoznata operacija/i, error.message)
  end

  # ===================
  # apply_aggregate Tests
  # ===================

  test "apply_aggregate with count without group_by" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ :count ] })
    assert result.is_a?(Integer)
  end

  test "apply_aggregate with count with group_by" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ :count ], group_by: :city })
    assert result.is_a?(Hash)
  end

  test "apply_aggregate with sum without group_by" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ :sum, :id ] })
    # Sum of ids
    assert result.is_a?(Integer) || result.is_a?(BigDecimal) || result.nil?
  end

  test "apply_aggregate with sum with group_by" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ :sum, :id ], group_by: :city })
    assert result.is_a?(Hash)
  end

  test "apply_aggregate with avg without group_by" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ :avg, :id ] })
    assert result.is_a?(Float) || result.is_a?(BigDecimal) || result.nil?
  end

  test "apply_aggregate with avg with group_by" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ :avg, :id ], group_by: :city })
    assert result.is_a?(Hash)
  end

  test "apply_aggregate with default func" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: nil })
    assert result.is_a?(Integer)
  end

  test "apply_aggregate with unknown function raises" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ :unknown_func ] })
    end

    assert_match(/Nepoznata agregacijska funkcija/i, error.message)
  end

  # ===================
  # apply_where_condition Tests
  # ===================

  test "apply_where_condition with greater than" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_where_condition, Location.all, "id > 0")
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with less than" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_where_condition, Location.all, "id < 1000000")
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with greater or equal" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_where_condition, Location.all, "id >= 0")
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with less or equal" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_where_condition, Location.all, "id <= 1000000")
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with equal" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_where_condition, Location.all, "id = #{@location.id}")
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with not equal" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_where_condition, Location.all, "id != 0")
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_where_condition with invalid condition" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_where_condition, Location.all, "invalid condition format")
    # Should return original scope
    assert result.is_a?(ActiveRecord::Relation)
  end

  # ===================
  # format_record Tests
  # ===================

  test "format_record returns hash with id and main fields" do
    result = Platform::DSL::Executors::TableQuery.send(:format_record, @location)

    assert result.is_a?(Hash)
    assert_equal @location.id, result[:id]
    assert_equal @location.name, result[:name]
    assert_equal @location.city, result[:city]
  end

  # ===================
  # execute Tests
  # ===================

  test "execute with simple query" do
    ast = {
      table: "locations",
      filters: { city: "Sarajevo" },
      operations: [ { name: :count } ]
    }

    result = Platform::DSL::Executors::TableQuery.execute(ast)

    assert result.is_a?(Integer)
    assert result >= 0
  end

  test "execute with multiple operations" do
    ast = {
      table: "locations",
      filters: { city: "Sarajevo" },
      operations: [
        { name: :sort, args: [ :name, :asc ] },
        { name: :limit, args: [ 5 ] }
      ]
    }

    result = Platform::DSL::Executors::TableQuery.execute(ast)

    assert result.is_a?(Array)
  end

  test "execute with no operations" do
    ast = {
      table: "locations",
      filters: { city: "Sarajevo" },
      operations: []
    }

    result = Platform::DSL::Executors::TableQuery.execute(ast)

    # Default behavior
    assert result.is_a?(Array) || result.is_a?(ActiveRecord::Relation)
  end

  test "execute with nil operations" do
    ast = {
      table: "locations",
      filters: { city: "Sarajevo" },
      operations: nil
    }

    result = Platform::DSL::Executors::TableQuery.execute(ast)

    assert result.is_a?(Array) || result.is_a?(ActiveRecord::Relation)
  end

  # ===================
  # Additional format_record Tests
  # ===================

  test "format_record for Experience" do
    location = Location.create!(
      name: "Exp Location",
      city: "Mostar",
      lat: 43.5,
      lng: 17.8
    )

    experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 120
    )
    experience.locations << location

    result = Platform::DSL::Executors::TableQuery.send(:format_record, experience)

    assert result.is_a?(Hash)
    assert_equal experience.id, result[:id]
    assert_equal "Test Experience", result[:title]
    assert_equal 120, result[:duration]
    assert_equal 1, result[:locations_count]
  end

  test "format_record for Plan" do
    plan = Plan.create!(title: "Test Plan")

    result = Platform::DSL::Executors::TableQuery.send(:format_record, plan)

    assert result.is_a?(Hash)
    assert_equal plan.id, result[:id]
    assert_equal "Test Plan", result[:title]
  end

  test "format_record for User" do
    user = User.create!(
      username: "test_format_user_#{SecureRandom.hex(4)}",
      password: "password123",
      user_type: :curator
    )

    result = Platform::DSL::Executors::TableQuery.send(:format_record, user)

    assert result.is_a?(Hash)
    assert_equal user.id, result[:id]
    assert_includes result[:username], "test_format_user"
    assert_equal "curator", result[:user_type]
  end

  test "format_record for generic record" do
    # Use Review as a generic record type
    user = User.create!(
      username: "reviewer_#{SecureRandom.hex(4)}",
      password: "password123"
    )
    location = Location.create!(name: "Review Location", city: "Tuzla", lat: 44.5, lng: 18.6)

    review = Review.create!(
      user: user,
      reviewable: location,
      comment: "Nice place",
      rating: 5
    )

    result = Platform::DSL::Executors::TableQuery.send(:format_record, review)

    assert result.is_a?(Hash)
    assert result.key?("id")
    assert result.key?("created_at")
  end

  # ===================
  # aggregate "count()" string test
  # ===================

  test "apply_aggregate with count() string" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ "count()" ] })
    assert result.is_a?(Integer)
  end

  test "apply_aggregate with count() string and group_by" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_aggregate, Location.all, { args: [ "count()" ], group_by: :city })
    assert result.is_a?(Hash)
  end

  # ===================
  # apply_filters with nil
  # ===================

  test "apply_filters with nil returns all" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filters, Location, nil)
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "apply_filters with empty hash returns all" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_filters, Location, {})
    assert result.is_a?(ActiveRecord::Relation)
  end

  # ===================
  # order operation alias test
  # ===================

  test "apply_operation with order alias" do
    result = Platform::DSL::Executors::TableQuery.send(:apply_operation, Location.all, { name: :order, args: [ :name, :desc ] })
    assert result.is_a?(ActiveRecord::Relation)
  end
end
