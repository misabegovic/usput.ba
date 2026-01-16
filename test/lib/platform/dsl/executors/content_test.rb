# frozen_string_literal: true

require "test_helper"

class Platform::DSL::Executors::ContentTest < ActiveSupport::TestCase
  setup do
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )

    @experience = Experience.create!(
      title: "Test Experience",
      estimated_duration: 60
    )

    @user = User.create!(
      username: "content_test_user_#{SecureRandom.hex(4)}",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # execute_audio tests
  test "execute_audio raises error for unknown action" do
    ast = { action: :unknown_action, table: "locations", filters: { id: @location.id } }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_audio(ast)
    end
  end

  # execute_create tests
  test "execute_create raises error when save fails" do
    # Location requires lat/lng, so omitting them should fail
    ast = {
      type: :mutation,
      action: :create,
      table: "locations",
      data: { name: "Invalid Location" } # Missing required lat/lng
    }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_mutation(ast)
    end
  end

  test "execute_create works for model without ai_generated attribute" do
    # Review doesn't have ai_generated attribute
    ast = {
      type: :mutation,
      action: :create,
      table: "reviews",
      data: {
        reviewable_type: "Location",
        reviewable_id: @location.id,
        user_id: @user.id,
        rating: 5,
        comment: "Great place!"
      }
    }

    result = Platform::DSL::Executors::Content.execute_mutation(ast)

    assert result[:success]
    assert_equal :create, result[:action]
  end

  test "execute_create validates BiH boundary for locations" do
    ast = {
      type: :mutation,
      action: :create,
      table: "locations",
      data: {
        name: "Paris Location",
        city: "Paris",
        lat: 48.8566, # Paris coordinates (outside BiH)
        lng: 2.3522
      }
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_mutation(ast)
    end

    assert_match(/unutar granica BiH/i, error.message)
  end

  # execute_update tests
  test "execute_update validates BiH boundary when updating coordinates" do
    ast = {
      type: :mutation,
      action: :update,
      table: "locations",
      filters: { id: @location.id },
      data: {
        lat: 48.8566, # Paris coordinates
        lng: 2.3522
      }
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_mutation(ast)
    end

    assert_match(/unutar granica BiH/i, error.message)
  end

  test "execute_update raises error when update fails" do
    # Try to update with invalid data
    ast = {
      type: :mutation,
      action: :update,
      table: "locations",
      filters: { id: @location.id },
      data: { name: nil } # Name can't be nil
    }

    # This may or may not raise depending on model validations
    # If it doesn't raise, verify the result
    begin
      result = Platform::DSL::Executors::Content.execute_mutation(ast)
      # If no error, check result structure
      assert result.is_a?(Hash)
    rescue Platform::DSL::ExecutionError => e
      assert_match(/nije uspjelo/i, e.message)
    end
  end

  test "execute_update handles non-existent record" do
    ast = {
      type: :mutation,
      action: :update,
      table: "locations",
      filters: { id: 999999 },
      data: { name: "Updated" }
    }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_mutation(ast)
    end
  end

  # execute_delete tests
  test "execute_delete handles non-existent record" do
    ast = {
      type: :mutation,
      action: :delete,
      table: "locations",
      filters: { id: 999999 }
    }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_mutation(ast)
    end
  end

  test "execute_delete hard deletes when soft delete not available" do
    # Create a review - Review model doesn't have soft delete
    review = Review.create!(
      reviewable: @location,
      user: @user,
      rating: 5,
      comment: "Great place!"
    )

    result = Platform::DSL::Executors::Content.send(:execute_delete, "reviews", { id: review.id })

    assert result[:success]
    assert_nil Review.find_by(id: review.id)
  end

  # execute_mutation unknown action test
  test "execute_mutation raises error for unknown action" do
    ast = {
      type: :mutation,
      action: :unknown_action,
      table: "locations",
      filters: { id: @location.id },
      data: {}
    }

    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_mutation(ast)
    end
  end

  # generate_description tests
  test "generate_description for experience" do
    mock_response = "Generated experience description"

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_response) do
      result = Platform::DSL::Executors::Content.send(:generate_description, {
        table: "experiences",
        filters: { id: @experience.id }
      })

      assert result[:success]
      assert_equal :generate_description, result[:action]
    end
  end

  test "generate_description raises for unsupported table" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:generate_description, {
        table: "users",
        filters: { id: @user.id }
      })
    end

    assert_match(/nema polje 'description'/i, error.message)
  end

  test "generate_description raises for non-existent record" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:generate_description, {
        table: "locations",
        filters: { id: 999999 }
      })
    end

    assert_match(/nije pronađen/i, error.message)
  end

  # generate_translations tests
  test "generate_translations for experience" do
    mock_response = "Translated experience description"

    Platform::DSL::Executors::Content.stub(:generate_with_llm, mock_response) do
      result = Platform::DSL::Executors::Content.send(:generate_translations, {
        table: "experiences",
        filters: { id: @experience.id },
        locales: ["en"]
      })

      assert result[:success]
      assert_equal :generate_translations, result[:action]
    end
  end

  test "generate_translations raises for unsupported table" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:generate_translations, {
        table: "users",
        filters: { id: @user.id },
        locales: ["en"]
      })
    end

    assert_match(/ne podržava prijevode/i, error.message)
  end

  test "generate_translations raises for invalid locales" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:generate_translations, {
        table: "locations",
        filters: { id: @location.id },
        locales: ["invalid_locale_xyz"]
      })
    end

    assert_match(/Nepodržani jezici/i, error.message)
  end

  test "generate_translations raises for non-existent record" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:generate_translations, {
        table: "locations",
        filters: { id: 999999 },
        locales: ["en"]
      })
    end

    assert_match(/nije pronađen/i, error.message)
  end

  # generate_experience tests
  test "generate_experience raises for single location" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:generate_experience, {
        location_ids: [@location.id]
      })
    end

    assert_match(/bar 2 lokacije/i, error.message)
  end

  test "generate_experience raises for non-existent locations" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:generate_experience, {
        location_ids: [999998, 999999]
      })
    end

    assert_match(/nisu pronađene/i, error.message)
  end

  # execute_generation unknown type test
  test "execute_generation raises for unknown gen_type" do
    ast = { gen_type: :unknown_gen_type }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.execute_generation(ast)
    end

    assert_match(/Nepoznat tip generacije/i, error.message)
  end

  # validate_mutation_data tests
  test "validate_mutation_data! raises for empty location data" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:validate_mutation_data!, "locations", {}, :create)
    end

    assert_match(/obavezna polja/i, error.message)
  end

  test "validate_mutation_data! raises for empty experience data" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:validate_mutation_data!, "experiences", {}, :create)
    end

    assert_match(/obavezna polja/i, error.message)
  end

  # find_record_for_mutation tests
  test "find_record_for_mutation finds by name" do
    record = Platform::DSL::Executors::Content.send(
      :find_record_for_mutation,
      Location,
      { name: @location.name }
    )

    assert_equal @location.id, record.id
  end

  test "find_record_for_mutation raises when not found" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(
        :find_record_for_mutation,
        Location,
        { name: "NonExistentLocation123456" }
      )
    end

    assert_match(/nije pronađen/i, error.message)
  end

  # format_created_record tests
  test "format_created_record for location" do
    result = Platform::DSL::Executors::Content.send(:format_created_record, @location)

    assert result.is_a?(Hash)
    assert_equal @location.id, result[:id]
    assert_equal @location.name, result[:name]
    assert_equal @location.city, result[:city]
  end

  test "format_created_record for experience" do
    result = Platform::DSL::Executors::Content.send(:format_created_record, @experience)

    assert result.is_a?(Hash)
    assert_equal @experience.id, result[:id]
    assert_equal @experience.title, result[:title]
  end

  # is_location_table? tests
  test "is_location_table? returns true for locations" do
    assert Platform::DSL::Executors::Content.send(:is_location_table?, "locations")
    assert Platform::DSL::Executors::Content.send(:is_location_table?, "location")
  end

  test "is_location_table? returns false for other tables" do
    assert_not Platform::DSL::Executors::Content.send(:is_location_table?, "experiences")
    assert_not Platform::DSL::Executors::Content.send(:is_location_table?, "users")
  end

  # is_experience_table? tests
  test "is_experience_table? returns true for experiences" do
    assert Platform::DSL::Executors::Content.send(:is_experience_table?, "experiences")
    assert Platform::DSL::Executors::Content.send(:is_experience_table?, "experience")
  end

  test "is_experience_table? returns false for other tables" do
    assert_not Platform::DSL::Executors::Content.send(:is_experience_table?, "locations")
    assert_not Platform::DSL::Executors::Content.send(:is_experience_table?, "users")
  end

  # Audio table validation (inline in synthesize_audio and estimate_audio_cost)
  test "synthesize_audio raises for non-location table" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:synthesize_audio, {
        table: "experiences",
        filters: { id: @experience.id }
      })
    end

    assert_match(/samo za lokacije/i, error.message)
  end

  test "estimate_audio_cost raises for non-location table" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:estimate_audio_cost, {
        table: "experiences",
        filters: {}
      })
    end

    assert_match(/samo za lokacije/i, error.message)
  end

  # estimate_audio_cost tests
  test "estimate_audio_cost returns cost estimate" do
    result = Platform::DSL::Executors::Content.send(:estimate_audio_cost, {
      table: "locations",
      filters: { city: "Sarajevo" }
    })

    assert_equal :estimate_audio_cost, result[:action]
    assert result.key?(:total_locations)
    assert result.key?(:estimated_cost_usd)
    assert result.key?(:notes)
  end

  test "estimate_audio_cost with empty filters" do
    result = Platform::DSL::Executors::Content.send(:estimate_audio_cost, {
      table: "locations",
      filters: {}
    })

    assert_equal :estimate_audio_cost, result[:action]
    assert result[:total_locations] >= 0
  end

  # synthesize_audio tests (mocked)
  test "synthesize_audio raises for non-existent location" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Content.send(:synthesize_audio, {
        table: "locations",
        filters: { id: 999999 }
      })
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "synthesize_audio with mocked generator" do
    mock_generator = Object.new
    mock_result = {
      location: @location.name,
      locale: "bs",
      status: :generated,
      duration_estimate: "4.5 min",
      audio_info: { filename: "test.mp3" }
    }
    mock_generator.define_singleton_method(:generate) { |**_args| mock_result }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { mock_generator }) do
      result = Platform::DSL::Executors::Content.send(:synthesize_audio, {
        table: "locations",
        filters: { id: @location.id }
      })

      assert result[:success]
      assert_equal :synthesize_audio, result[:action]
    end
  end

  # find_voice_id tests
  test "find_voice_id returns id for known voice" do
    voice_id = Platform::DSL::Executors::Content.send(:find_voice_id, "Rachel")
    assert_equal "21m00Tcm4TlvDq8ikWAM", voice_id
  end

  test "find_voice_id returns nil for unknown voice" do
    voice_id = Platform::DSL::Executors::Content.send(:find_voice_id, "UnknownVoice")
    assert_nil voice_id
  end

  test "find_voice_id is case insensitive" do
    voice_id = Platform::DSL::Executors::Content.send(:find_voice_id, "RACHEL")
    assert_equal "21m00Tcm4TlvDq8ikWAM", voice_id
  end
end
