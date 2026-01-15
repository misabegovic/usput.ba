# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ExternalTest < ActiveSupport::TestCase
  setup do
    @sarajevo_location = Location.create!(
      name: "Baščaršija",
      city: "Sarajevo",
      lat: 43.8598,
      lng: 18.4313
    )
    @mostar_location = Location.create!(
      name: "Stari Most",
      city: "Mostar",
      lat: 43.3372,
      lng: 17.8150
    )
  end

  # validate_location tests (no API calls needed)
  test "validates location inside BiH" do
    result = Platform::DSL.execute('external { lat: 43.8563, lng: 18.4131 } | validate_location')

    assert_kind_of Hash, result
    assert_equal true, result[:in_bih]
    assert_equal true, result[:valid]
    assert_in_delta 43.8563, result[:lat], 0.001
    assert_in_delta 18.4131, result[:lng], 0.001
  end

  test "validates location outside BiH" do
    # Belgrade coordinates
    result = Platform::DSL.execute('external { lat: 44.82, lng: 20.45 } | validate_location')

    assert_kind_of Hash, result
    assert_equal false, result[:in_bih]
    assert_equal false, result[:valid]
    assert result[:distance_to_border_km] > 0
    assert_equal "Lokacija je van granica Bosne i Hercegovine", result[:message]
  end

  test "validate shorthand works" do
    result = Platform::DSL.execute('external { lat: 43.8563, lng: 18.4131 } | validate')

    assert_kind_of Hash, result
    assert_equal true, result[:valid]
  end

  # check_duplicate tests (database only, no API)
  test "finds duplicate by name" do
    result = Platform::DSL.execute('external { name: "Baščaršija" } | check_duplicate')

    assert_kind_of Hash, result
    assert_equal true, result[:has_duplicates]
    assert result[:count] >= 1
    assert_equal :name, result[:duplicates].first[:match_type]
  end

  test "finds duplicate by proximity" do
    # Very close to existing location
    result = Platform::DSL.execute('external { lat: 43.8598, lng: 18.4313 } | check_duplicate')

    assert_kind_of Hash, result
    # Should find the nearby location
    if result[:has_duplicates]
      assert result[:duplicates].any? { |d| d[:match_type] == :proximity }
    end
  end

  test "no duplicates for unique location" do
    result = Platform::DSL.execute('external { name: "Completely Unique Name XYZ123" } | check_duplicate')

    assert_kind_of Hash, result
    assert_equal false, result[:has_duplicates]
    assert_equal 0, result[:count]
  end

  test "dedupe shorthand works" do
    result = Platform::DSL.execute('external { name: "Stari" } | dedupe')

    assert_kind_of Hash, result
    # Should find Stari Most
    assert result[:has_duplicates]
  end

  # Error handling tests
  test "raises error for validate without coordinates" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('external | validate_location')
    end
  end

  test "raises error for check_duplicate without name or coordinates" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('external | check_duplicate')
    end
  end

  test "raises error for unknown external operation" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('external | unknown_operation')
    end
  end

  # Parser integration tests
  test "parses external command correctly" do
    ast = Platform::DSL::Parser.parse('external { city: "Sarajevo" } | search_pois')

    assert_equal :external_query, ast[:type]
    assert_equal "Sarajevo", ast[:filters][:city]
    assert_equal :search_pois, ast[:operations].first[:name]
  end

  test "parses external with multiple filters" do
    ast = Platform::DSL::Parser.parse('external { lat: 43.85, lng: 18.41 } | validate')

    assert_equal :external_query, ast[:type]
    assert_in_delta 43.85, ast[:filters][:lat], 0.01
    assert_in_delta 18.41, ast[:filters][:lng], 0.01
    assert_equal :validate, ast[:operations].first[:name]
  end
end
