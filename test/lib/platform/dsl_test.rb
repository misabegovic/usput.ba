# frozen_string_literal: true

require "test_helper"

class Platform::DSLTest < ActiveSupport::TestCase
  test "execute returns result for valid query" do
    result = Platform::DSL.execute("locations | count")

    assert result.is_a?(Integer)
  end

  test "execute raises ParseError for invalid DSL" do
    error = assert_raises(Platform::DSL::ParseError) do
      Platform::DSL.execute("completely !@#$% invalid query")
    end

    # Just verify we got an error with a message
    assert error.message.present?
  end

  test "parse returns AST for valid query" do
    result = Platform::DSL.parse("locations | count")

    assert result.is_a?(Hash)
    assert_equal :table_query, result[:type]
    assert_equal "locations", result[:table]
  end

  test "parse raises for invalid query" do
    assert_raises(Platform::DSL::ParseError) do
      Platform::DSL.parse("!@#$ invalid")
    end
  end

  test "validate returns validation result" do
    result = Platform::DSL.validate("schema | stats")

    assert result.is_a?(Hash)
    assert result.key?(:valid)
    assert result[:valid]
  end

  test "validate returns errors for invalid query" do
    result = Platform::DSL.validate("unknown_table | count")

    assert result.is_a?(Hash)
    assert result.key?(:valid)
    refute result[:valid]
    assert result[:errors].any?
  end

  test "ParseError is defined" do
    assert_kind_of Class, Platform::DSL::ParseError
    assert Platform::DSL::ParseError < StandardError
  end

  test "ExecutionError is defined" do
    assert_kind_of Class, Platform::DSL::ExecutionError
    assert Platform::DSL::ExecutionError < StandardError
  end

  test "execute with Parslet::ParseFailed" do
    # Force a Parslet::ParseFailed error through an edge case
    Platform::DSL::Parser.stub(:parse, ->(_) { raise Parslet::ParseFailed.new("Test error", nil) }) do
      error = assert_raises(Platform::DSL::ParseError) do
        Platform::DSL.execute("test query")
      end

      assert error.message.include?("Neispravan DSL")
    end
  end
end
