# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ValidatorTest < ActiveSupport::TestCase
  test "validates valid schema query" do
    result = Platform::DSL::Validator.validate("schema | stats")

    assert result[:valid]
    assert_empty result[:errors]
    assert_equal :low, result[:estimated_cost]
  end

  test "validates valid table query" do
    result = Platform::DSL::Validator.validate("locations { city: \"Sarajevo\" } | count")

    assert result[:valid]
    assert_empty result[:errors]
  end

  test "returns error for invalid table" do
    result = Platform::DSL::Validator.validate("invalid_table { } | count")

    refute result[:valid]
    assert_includes result[:errors].first, "Nepoznata tabela"
  end

  test "returns error for invalid operation" do
    result = Platform::DSL::Validator.validate("locations | invalid_op")

    refute result[:valid]
    assert result[:errors].any? { |e| e.include?("Nepoznata operacija") }
  end

  test "returns parse error for invalid syntax" do
    result = Platform::DSL::Validator.validate("!@#$%^")

    refute result[:valid]
    assert result[:errors].any?
    assert_equal :unknown, result[:estimated_cost]
    assert_nil result[:ast]
  end

  test "estimates low cost for schema queries" do
    result = Platform::DSL::Validator.validate("schema | stats")
    assert_equal :low, result[:estimated_cost]
  end

  test "estimates low cost for queries with strong filters" do
    result = Platform::DSL::Validator.validate("locations { id: 1 } | sample 5")
    assert_equal :low, result[:estimated_cost]
  end

  test "estimates low cost for queries with limit operations" do
    result = Platform::DSL::Validator.validate("locations | count")
    assert_equal :low, result[:estimated_cost]
  end

  test "estimates medium cost for queries with weak filters" do
    result = Platform::DSL::Validator.validate("locations { rating: 4.5 }")
    assert_equal :medium, result[:estimated_cost]
  end

  test "estimates high cost for queries without filters or limits" do
    result = Platform::DSL::Validator.validate("locations")
    assert_equal :high, result[:estimated_cost]
  end

  test "warns about high cost queries" do
    result = Platform::DSL::Validator.validate("locations")

    assert result[:warnings].any? { |w| w.include?("spor") }
  end

  test "warns about queries without operations" do
    result = Platform::DSL::Validator.validate("locations { city: \"Mostar\" }")

    assert result[:warnings].any? { |w| w.include?("nema operacija") }
  end

  test "valid_operation? returns true for known operations" do
    validator = Platform::DSL::Validator

    assert validator.send(:valid_operation?, :stats)
    assert validator.send(:valid_operation?, :count)
    assert validator.send(:valid_operation?, :sample)
    assert validator.send(:valid_operation?, :aggregate)
    assert validator.send(:valid_operation?, :where)
    assert validator.send(:valid_operation?, :select)
    assert validator.send(:valid_operation?, :sort)
  end

  test "valid_operation? returns false for unknown operations" do
    validator = Platform::DSL::Validator

    refute validator.send(:valid_operation?, :unknown_op)
    refute validator.send(:valid_operation?, :bad)
  end

  test "VALID_TABLES includes expected tables" do
    tables = Platform::DSL::Validator::VALID_TABLES

    assert_includes tables, "locations"
    assert_includes tables, "experiences"
    assert_includes tables, "plans"
  end

  test "returns ast in result" do
    result = Platform::DSL::Validator.validate("schema | stats")

    assert_not_nil result[:ast]
    assert_equal :schema_query, result[:ast][:type]
  end
end
