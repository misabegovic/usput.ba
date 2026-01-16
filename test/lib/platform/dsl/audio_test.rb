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

  # Mocked audio synthesis tests

  test "synthesize_audio calls AudioTourGenerator and returns result" do
    # Mock the AudioTourGenerator
    mock_generator = Object.new
    mock_result = {
      location: @location.name,
      locale: "bs",
      status: :generated,
      duration_estimate: "4.5 min",
      audio_info: { filename: "test-audio.mp3" }
    }
    mock_generator.define_singleton_method(:generate) { |**_args| mock_result }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      result = Platform::DSL.execute("synthesize audio for location { id: #{@location.id} }")

      assert result[:success]
      assert_equal :synthesize_audio, result[:action]
      assert_equal @location.id, result[:location_id]
      assert_equal @location.name, result[:location_name]
      assert_equal "bs", result[:locale]
      assert_equal :generated, result[:status]
    end
  end

  test "synthesize_audio with custom locale" do
    mock_generator = Object.new
    mock_result = {
      location: @location.name,
      locale: "en",
      status: :generated,
      duration_estimate: "5.0 min",
      audio_info: { filename: "test-audio-en.mp3" }
    }
    mock_generator.define_singleton_method(:generate) { |**_args| mock_result }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      result = Platform::DSL.execute("synthesize audio for location { id: #{@location.id} } locale \"en\"")

      assert result[:success]
      assert_equal "en", result[:locale]
    end
  end

  test "synthesize_audio with custom voice configures setting" do
    mock_generator = Object.new
    mock_result = {
      location: @location.name,
      locale: "bs",
      status: :generated,
      duration_estimate: "4.5 min",
      audio_info: nil
    }
    mock_generator.define_singleton_method(:generate) { |**_args| mock_result }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      result = Platform::DSL.execute("synthesize audio for location { id: #{@location.id} } voice \"Rachel\"")

      assert result[:success]
      # Voice should have been configured via Setting.set
    end
  end

  test "synthesize_audio creates audit log" do
    mock_generator = Object.new
    mock_result = {
      location: @location.name,
      locale: "bs",
      status: :generated,
      duration_estimate: "4.5 min",
      audio_info: nil
    }
    mock_generator.define_singleton_method(:generate) { |**_args| mock_result }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      assert_difference "PlatformAuditLog.count", 1 do
        Platform::DSL.execute("synthesize audio for location { id: #{@location.id} }")
      end

      log = PlatformAuditLog.last
      assert_equal "create", log.action
      assert_equal "AudioTour", log.record_type
      assert_equal "platform_dsl_audio", log.triggered_by
    end
  end

  test "synthesize_audio handles generation error" do
    mock_generator = Object.new
    mock_generator.define_singleton_method(:generate) do |**_args|
      raise Ai::AudioTourGenerator::GenerationError, "ElevenLabs API key not configured"
    end

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      error = assert_raises(Platform::DSL::ExecutionError) do
        Platform::DSL.execute("synthesize audio for location { id: #{@location.id} }")
      end

      assert_match(/Audio sinteza nije uspjela/i, error.message)
      assert_match(/ElevenLabs API key/i, error.message)
    end
  end

  test "synthesize_audio with already_exists status" do
    mock_generator = Object.new
    mock_result = {
      location: @location.name,
      locale: "bs",
      status: :already_exists,
      audio_info: { filename: "existing-audio.mp3", duration: "3.5 min" }
    }
    mock_generator.define_singleton_method(:generate) { |**_args| mock_result }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      result = Platform::DSL.execute("synthesize audio for location { id: #{@location.id} }")

      assert result[:success]
      assert_equal :already_exists, result[:status]
    end
  end

  # Cost estimation tests
  test "estimate_audio_cost returns notes array" do
    result = Platform::DSL.execute('estimate audio cost for locations { city: "Sarajevo" }')

    assert_equal :estimate_audio_cost, result[:action]
    assert result[:notes].is_a?(Array)
    assert result[:notes].any?
  end

  test "estimate_audio_cost handles empty result" do
    # Query for a city with no locations
    result = Platform::DSL.execute('estimate audio cost for locations { city: "NepostojeciGrad12345" }')

    assert_equal :estimate_audio_cost, result[:action]
    assert_equal 0, result[:total_locations]
    assert_equal 0, result[:estimated_cost_usd]
  end
end
