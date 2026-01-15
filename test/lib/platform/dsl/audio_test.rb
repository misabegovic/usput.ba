# frozen_string_literal: true

require "test_helper"

class Platform::DSL::AudioTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Lokacija",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      description: "Opis za audio turu"
    )

    @location2 = Location.create!(
      name: "Druga Lokacija",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      description: "Drugi opis"
    )
  end

  # Parser tests
  test "parses synthesize audio command" do
    ast = Platform::DSL::Parser.parse('synthesize audio for location { id: 123 }')

    assert_equal :audio, ast[:type]
    assert_equal :synthesize, ast[:action]
    assert_equal :audio, ast[:audio_type]
    assert_equal "location", ast[:table]
    assert_equal 123, ast[:filters][:id]
  end

  test "parses synthesize audio with locale" do
    ast = Platform::DSL::Parser.parse('synthesize audio for location { id: 123 } locale "en"')

    assert_equal :audio, ast[:type]
    assert_equal :synthesize, ast[:action]
    assert_equal "en", ast[:locale]
  end

  test "parses synthesize audio with voice" do
    ast = Platform::DSL::Parser.parse('synthesize audio for location { id: 123 } voice "Rachel"')

    assert_equal :audio, ast[:type]
    assert_equal :synthesize, ast[:action]
    assert_equal "Rachel", ast[:voice]
  end

  test "parses synthesize audio with locale and voice" do
    ast = Platform::DSL::Parser.parse('synthesize audio for location { id: 123 } locale "de" voice "Adam"')

    assert_equal :audio, ast[:type]
    assert_equal "de", ast[:locale]
    assert_equal "Adam", ast[:voice]
  end

  test "parses estimate audio cost command" do
    ast = Platform::DSL::Parser.parse('estimate audio cost for locations { city: "Mostar" }')

    assert_equal :audio, ast[:type]
    assert_equal :estimate, ast[:action]
    assert_equal :cost, ast[:audio_type]
    assert_equal "locations", ast[:table]
    assert_equal "Mostar", ast[:filters][:city]
  end

  # Cost estimation tests (no API calls)
  test "estimates audio cost for locations" do
    result = Platform::DSL.execute('estimate audio cost for locations { city: "Sarajevo" }')

    assert_equal :estimate_audio_cost, result[:action]
    assert result[:total_locations] >= 1
    assert result[:estimated_cost_usd] > 0
    assert result[:by_city].key?("Sarajevo")
    assert result[:notes].present?
  end

  test "estimates audio cost with breakdown by city" do
    result = Platform::DSL.execute('estimate audio cost for locations { }')

    assert_equal :estimate_audio_cost, result[:action]
    assert result[:total_locations] >= 2
    assert result[:by_city].present?
  end

  # Error handling
  test "rejects audio synthesis for non-location tables" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('synthesize audio for experience { id: 1 }')
    end

    assert_match(/samo za lokacije/i, error.message)
  end

  test "rejects audio cost estimation for non-location tables" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('estimate audio cost for experiences { }')
    end

    assert_match(/samo za lokacije/i, error.message)
  end

  test "rejects synthesize for non-existent location" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('synthesize audio for location { id: 999999 }')
    end

    assert_match(/nije pronađen/i, error.message)
  end

  # Voice lookup test
  test "finds voice id by name" do
    voice_id = Platform::DSL::Executor.send(:find_voice_id, "Rachel")
    assert_equal "21m00Tcm4TlvDq8ikWAM", voice_id

    voice_id = Platform::DSL::Executor.send(:find_voice_id, "adam")
    assert_equal "pNInz6obpgDQGcFmaJgB", voice_id
  end

  test "returns nil for unknown voice" do
    voice_id = Platform::DSL::Executor.send(:find_voice_id, "UnknownVoice")
    assert_nil voice_id
  end

  # Note: Actual audio synthesis tests would require mocking ElevenLabs API
  # These tests verify the DSL parsing and cost estimation without API calls
end
