# frozen_string_literal: true

require "test_helper"

class Platform::DSL::GenerationTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Lokacija",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      description: "Originalni opis"
    )

    @location2 = Location.create!(
      name: "Druga Lokacija",
      city: "Sarajevo",
      lat: 43.8600,
      lng: 18.4200,
      description: "Drugi opis"
    )
  end

  # Parser tests
  test "parses generate description command" do
    ast = Platform::DSL::Parser.parse('generate description for location { id: 123 }')

    assert_equal :generation, ast[:type]
    assert_equal :description, ast[:gen_type]
    assert_equal "location", ast[:table]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses generate description with style" do
    ast = Platform::DSL::Parser.parse('generate description for location { id: 123 } style "vivid"')

    assert_equal :generation, ast[:type]
    assert_equal :description, ast[:gen_type]
    assert_equal "vivid", ast[:style]
  end

  test "parses generate translations command" do
    ast = Platform::DSL::Parser.parse('generate translations for location { id: 123 } to ["en", "de", "fr"]')

    assert_equal :generation, ast[:type]
    assert_equal :translations, ast[:gen_type]
    assert_equal "location", ast[:table]
    assert_includes ast[:locales], "en"
    assert_includes ast[:locales], "de"
    assert_includes ast[:locales], "fr"
  end

  test "parses generate experience command" do
    ast = Platform::DSL::Parser.parse('generate experience from locations [1, 2, 3]')

    assert_equal :generation, ast[:type]
    assert_equal :experience, ast[:gen_type]
    assert_equal [1, 2, 3], ast[:location_ids]
  end

  # Execution tests with mocked LLM
  test "generates description with mocked LLM" do
    mock_response = "Ovo je generisani opis za test lokaciju u Sarajevu."

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_response) do
      result = Platform::DSL.execute("generate description for location { id: #{@location.id} }")

      assert result[:success]
      assert_equal :generate_description, result[:action]
      assert_equal @location.id, result[:record_id]

      @location.reload
      assert_equal mock_response, @location.description
    end
  end

  test "generates description with style" do
    mock_response = "Vivid opis lokacije."

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_response) do
      result = Platform::DSL.execute("generate description for location { id: #{@location.id} } style \"vivid\"")

      assert result[:success]
      assert_equal "vivid", result[:style]
    end
  end

  test "creates audit log for description generation" do
    mock_response = "Novi opis."

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_response) do
      assert_difference "PlatformAuditLog.count", 1 do
        Platform::DSL.execute("generate description for location { id: #{@location.id} }")
      end

      log = PlatformAuditLog.last
      assert_equal "update", log.action
      assert_equal "Location", log.record_type
      assert_equal "platform_dsl_generation", log.triggered_by
    end
  end

  test "generates translations with mocked LLM" do
    mock_response = "This is the English translation."

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_response) do
      result = Platform::DSL.execute("generate translations for location { id: #{@location.id} } to [\"en\"]")

      assert result[:success]
      assert_equal :generate_translations, result[:action]
      assert_includes result[:locales], "en"
      assert result[:translations_count] > 0
    end
  end

  test "rejects invalid locales" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("generate translations for location { id: #{@location.id} } to [\"invalid_locale\"]")
    end

    assert_match(/Nepodržani jezici/i, error.message)
  end

  test "generates experience with mocked LLM" do
    mock_json = '{"title": "Sarajevska Tura", "description": "Opis ture", "duration_hours": 3}'

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_json) do
      result = Platform::DSL.execute("generate experience from locations [#{@location.id}, #{@location2.id}]")

      assert result[:success]
      assert_equal :generate_experience, result[:action]
      assert result[:experience_id].present?
      assert_equal 2, result[:locations_count]

      # Verify experience was created
      experience = Experience.find(result[:experience_id])
      assert_equal "Sarajevska Tura", experience.title
      assert_equal 2, experience.locations.count
    end
  end

  test "rejects experience generation with less than 2 locations" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("generate experience from locations [#{@location.id}]")
    end

    assert_match(/bar 2 lokacije/i, error.message)
  end

  test "rejects experience generation with non-existent locations" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("generate experience from locations [999998, 999999]")
    end

    assert_match(/nisu pronađene/i, error.message)
  end

  test "creates audit log for experience generation" do
    mock_json = '{"title": "Test Tura", "description": "Opis", "duration_hours": 2}'

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_json) do
      assert_difference "PlatformAuditLog.count", 1 do
        Platform::DSL.execute("generate experience from locations [#{@location.id}, #{@location2.id}]")
      end

      log = PlatformAuditLog.last
      assert_equal "create", log.action
      assert_equal "Experience", log.record_type
    end
  end

  # Error handling
  test "raises error for non-existent record" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('generate description for location { id: 999999 }')
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "raises error for unknown generation type" do
    ast = { type: :generation, gen_type: :unknown }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.execute(ast)
    end

    assert_match(/Nepoznat tip generacije/i, error.message)
  end
end
