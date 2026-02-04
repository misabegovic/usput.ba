# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ContentValidatorTest < ActiveSupport::TestCase
  setup do
    # Create some test locations for duplicate detection
    @existing_location = Location.create!(
      name: "Stari most",
      city: "Mostar",
      lat: 43.3372,
      lng: 17.8150,
      ai_generated: true
    )
  end

  teardown do
    @existing_location&.destroy
  end

  # ===================
  # ValidationResult tests
  # ===================

  test "ValidationResult initializes with valid status" do
    result = Platform::DSL::ValidationResult.new
    assert result.valid?
    assert result.clean?
    assert_equal :valid, result.status
  end

  test "ValidationResult add_error sets status to invalid" do
    result = Platform::DSL::ValidationResult.new
    result.add_error("Test error", code: :test)

    refute result.valid?
    assert_equal :invalid, result.status
    assert_equal 1, result.errors.size
    assert_equal "Test error", result.errors.first[:message]
    assert_equal :test, result.errors.first[:code]
  end

  test "ValidationResult add_warning sets status to warning" do
    result = Platform::DSL::ValidationResult.new
    result.add_warning("Test warning", code: :test)

    assert result.valid? # warnings don't make it invalid
    refute result.clean?
    assert_equal :warning, result.status
    assert_equal 1, result.warnings.size
  end

  test "ValidationResult merge! combines results" do
    result1 = Platform::DSL::ValidationResult.new
    result1.add_warning("Warning 1")

    result2 = Platform::DSL::ValidationResult.new
    result2.add_error("Error 1")

    result1.merge!(result2)

    assert_equal :invalid, result1.status
    assert_equal 1, result1.warnings.size
    assert_equal 1, result1.errors.size
  end

  test "ValidationResult to_dsl_response returns correct format" do
    result = Platform::DSL::ValidationResult.new
    result.add_warning("Test warning")
    result.coordinates = { lat: 43.0, lng: 17.0 }

    response = result.to_dsl_response

    assert_equal :warning, response[:status]
    assert response[:valid]
    assert_equal 1, response[:warnings].size
    assert_equal({ lat: 43.0, lng: 17.0 }, response[:coordinates])
  end

  # ===================
  # ContentValidator.validate_location tests
  # ===================

  test "validate_location detects suspicious thermal pattern" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Rimske terme Tuzla",
      city: "Tuzla"
    )

    assert result.warnings.any? { |w| w[:code] == :suspicious_pattern_high }
  end

  test "validate_location detects suspicious spa pattern" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Wellness retreat Sarajevo",
      city: "Sarajevo"
    )

    assert result.warnings.any? { |w| w[:code] == :suspicious_pattern_high }
  end

  test "validate_location flags ambiguous city" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Some Location",
      city: "Tuzla"
    )

    assert result.warnings.any? { |w| w[:code] == :ambiguous_city }
  end

  test "validate_location detects wrong city for known location" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Kravica waterfall",
      city: "Posušje" # Wrong - should be Ljubuški
    )

    assert result.warnings.any? { |w| w[:code] == :wrong_city }
  end

  test "validate_location detects exact duplicate" do
    result = Platform::DSL::ContentValidator.validate_location(
      name: "Stari most",
      city: "Mostar"
    )

    assert result.errors.any? { |e| e[:code] == :duplicate_exact }
    refute result.valid?
  end

  test "validate_location passes for valid new location" do
    # Skip Geoapify for this test
    Platform::DSL::ContentValidator.stub(:check_geoapify, Platform::DSL::ValidationResult.new) do
      result = Platform::DSL::ContentValidator.validate_location(
        name: "Jedinstvena nova lokacija",
        city: "Sarajevo",
        lat: 43.8563,
        lng: 18.4131
      )

      # May have warnings but should be valid
      assert result.valid?
    end
  end

  # ===================
  # ContentValidator.validate_experience tests
  # ===================

  test "validate_experience requires minimum 2 locations" do
    result = Platform::DSL::ContentValidator.validate_experience(location_ids: [ 1 ])

    refute result.valid?
    assert result.errors.any? { |e| e[:code] == :insufficient_locations }
  end

  test "validate_experience detects missing locations" do
    result = Platform::DSL::ContentValidator.validate_experience(
      location_ids: [ @existing_location.id, 999999 ]
    )

    refute result.valid?
    assert result.errors.any? { |e| e[:code] == :locations_not_found }
  end

  test "validate_experience passes for valid locations" do
    loc1 = Location.create!(
      name: "Test Loc 1", city: "Mostar",
      lat: 43.34, lng: 17.81, ai_generated: true,
      description: "A" * 100
    )
    loc2 = Location.create!(
      name: "Test Loc 2", city: "Mostar",
      lat: 43.35, lng: 17.82, ai_generated: true,
      description: "B" * 100
    )

    result = Platform::DSL::ContentValidator.validate_experience(
      location_ids: [ loc1.id, loc2.id ]
    )

    assert result.valid?
  ensure
    loc1&.destroy
    loc2&.destroy
  end

  # ===================
  # ContentValidator.find_duplicates tests
  # ===================

  test "find_duplicates returns exact match" do
    duplicates = Platform::DSL::ContentValidator.find_duplicates("Stari most", "Mostar")

    assert duplicates.any? { |d| d[:match_type] == :exact && d[:id] == @existing_location.id }
  end

  test "find_duplicates returns empty for unique name" do
    duplicates = Platform::DSL::ContentValidator.find_duplicates(
      "Jedinstvena lokacija koja sigurno ne postoji ABC123"
    )

    assert_empty duplicates
  end

  # ===================
  # DSL Command Integration tests
  # ===================

  test "DSL parses validate location command" do
    ast = Platform::DSL::Parser.parse('validate location { name: "Test", city: "Mostar" }')

    assert_equal :validation, ast[:type]
    assert_equal :validate, ast[:action]
    assert_equal :location, ast[:validate_type]
    assert_equal "Test", ast[:data][:name]
    assert_equal "Mostar", ast[:data][:city]
  end

  test "DSL parses validate experience command" do
    ast = Platform::DSL::Parser.parse("validate experience from locations [1, 2, 3]")

    assert_equal :validation, ast[:type]
    assert_equal :validate, ast[:action]
    assert_equal :experience, ast[:validate_type]
    assert_equal [ 1, 2, 3 ], ast[:location_ids]
  end

  test "DSL parses scan suspicious patterns command" do
    ast = Platform::DSL::Parser.parse("scan suspicious patterns")

    assert_equal :validation, ast[:type]
    assert_equal :scan, ast[:action]
    assert_equal :suspicious, ast[:scan_type]
  end

  test "DSL parses find duplicates command" do
    ast = Platform::DSL::Parser.parse('find duplicates for location { name: "Test" }')

    assert_equal :validation, ast[:type]
    assert_equal :find_duplicates, ast[:action]
    assert_equal "Test", ast[:data][:name]
  end

  test "DSL executes validate location command" do
    # Skip Geoapify
    Platform::DSL::ContentValidator.stub(:check_geoapify, Platform::DSL::ValidationResult.new) do
      result = Platform::DSL.execute('validate location { name: "Nova lokacija", city: "Sarajevo" }')

      assert_equal "validate location", result[:command]
      assert result[:status].present?
    end
  end

  test "DSL executes scan suspicious patterns command" do
    result = Platform::DSL.execute("scan suspicious patterns")

    assert_equal "scan suspicious patterns", result[:command]
    assert result[:summary].present?
  end

  test "DSL executes find duplicates command" do
    result = Platform::DSL.execute('find duplicates for location { name: "Stari most" }')

    assert_equal "find duplicates", result[:command]
    assert result[:found] >= 1
  end

  # ===================
  # DSL Create with Validation tests
  # ===================

  test "DSL create location fails for exact duplicate" do
    # Try to create a duplicate of existing location
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('create location { name: "Stari most", city: "Mostar" }')
    end

    assert_match(/Validacija nije prošla/, error.message)
    assert_match(/već postoji/, error.message)
  end

  test "DSL create location fails for coordinates outside BiH" do
    # Skip Geoapify and use explicit coordinates outside BiH
    GeoapifyService.stub(:new, -> { raise "should not call" }) do
      error = assert_raises(Platform::DSL::ExecutionError) do
        Platform::DSL.execute('create location { name: "Test Outside BiH", city: "Zagreb", lat: 45.8150, lng: 15.9819 }')
      end

      assert_match(/BiH/, error.message)
    end
  end
end
