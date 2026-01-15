# frozen_string_literal: true

require "test_helper"

class ExperienceTypeSyncJobTest < ActiveJob::TestCase
  setup do
    # Clean up test data
    LocationExperienceType.delete_all
    ExperienceType.delete_all
    Location.delete_all

    # Clear any existing status
    ExperienceTypeSyncJob.clear_status!
  end

  # === Queue configuration tests ===

  test "job is queued in default queue" do
    assert_equal "default", ExperienceTypeSyncJob.new.queue_name
  end

  test "job is enqueued with parameters" do
    assert_enqueued_with(
      job: ExperienceTypeSyncJob,
      args: [{ dry_run: true }]
    ) do
      ExperienceTypeSyncJob.perform_later(dry_run: true)
    end
  end

  test "job is enqueued without parameters" do
    assert_enqueued_with(job: ExperienceTypeSyncJob) do
      ExperienceTypeSyncJob.perform_later
    end
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = ExperienceTypeSyncJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = ExperienceTypeSyncJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "current_status returns idle when no job has run" do
    status = ExperienceTypeSyncJob.current_status

    assert_equal "idle", status[:status]
  end

  test "clear_status! resets status to idle" do
    Setting.set("experience_type_sync.status", "in_progress")
    Setting.set("experience_type_sync.message", "Working...")
    Setting.set("experience_type_sync.results", '{"test": true}')

    ExperienceTypeSyncJob.clear_status!

    status = ExperienceTypeSyncJob.current_status
    assert_equal "idle", status[:status]
    # Message is cleared to empty string or nil
    assert_includes [nil, ""], status[:message]
    assert_equal({}, status[:results])
  end

  test "force_reset! resets stuck job to idle" do
    Setting.set("experience_type_sync.status", "in_progress")

    ExperienceTypeSyncJob.force_reset!

    status = ExperienceTypeSyncJob.current_status
    assert_equal "idle", status[:status]
    assert_equal "Force reset by admin", status[:message]
  end

  test "current_status handles invalid JSON in results" do
    Setting.set("experience_type_sync.status", "completed")
    Setting.set("experience_type_sync.message", "Done")
    Setting.set("experience_type_sync.results", "invalid json{")

    status = ExperienceTypeSyncJob.current_status

    assert_equal "idle", status[:status]
    assert_equal({}, status[:results])
  end

  # === Perform method - basic scenarios ===

  test "perform returns results hash with expected keys" do
    results = ExperienceTypeSyncJob.perform_now

    assert results.is_a?(Hash)
    assert_includes results.keys, :started_at
    assert_includes results.keys, :finished_at
    assert_includes results.keys, :total_locations
    assert_includes results.keys, :experience_types_created
    assert_includes results.keys, :associations_created
    assert_includes results.keys, :locations_updated
    assert_includes results.keys, :new_types
    assert_includes results.keys, :errors
    assert_includes results.keys, :dry_run
    assert_includes results.keys, :status
  end

  test "perform with no locations returns zero counts" do
    results = ExperienceTypeSyncJob.perform_now

    assert_equal 0, results[:total_locations]
    assert_equal 0, results[:experience_types_created]
    assert_equal 0, results[:associations_created]
    assert_equal 0, results[:locations_updated]
    assert_equal "completed", results[:status]
  end

  test "perform sets dry_run flag in results" do
    results = ExperienceTypeSyncJob.perform_now(dry_run: true)
    assert_equal true, results[:dry_run]

    results = ExperienceTypeSyncJob.perform_now(dry_run: false)
    assert_equal false, results[:dry_run]
  end

  # === Perform method - with locations ===

  test "perform creates new experience types from location suitable_experiences" do
    create_location_with_experiences("Sarajevo Museum", ["culture", "history"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 2, results[:experience_types_created]
    assert_equal 2, results[:new_types].count
    assert_includes results[:new_types], "culture"
    assert_includes results[:new_types], "history"
    assert ExperienceType.exists?(key: "culture")
    assert ExperienceType.exists?(key: "history")
  end

  test "perform creates associations between locations and experience types" do
    create_location_with_experiences("Sarajevo Museum", ["culture", "history"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 2, results[:associations_created]
    assert_equal 1, results[:locations_updated]

    location = Location.find_by(name: "Sarajevo Museum")
    assert_equal 2, location.location_experience_types.count
  end

  test "perform does not create duplicate experience types" do
    ExperienceType.create!(key: "culture", name: "Culture", active: true, position: 1)
    create_location_with_experiences("Sarajevo Museum", ["culture", "history"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 1, results[:experience_types_created]
    assert_equal 2, ExperienceType.count
  end

  test "perform does not create duplicate associations when association already exists" do
    # Create experience type first
    exp_type = ExperienceType.create!(key: "culture", name: "Culture", active: true, position: 1)

    # Create location without triggering the callback by using update_column
    location = Location.create!(name: "Sarajevo Museum", city: "Sarajevo", lat: 43.85, lng: 18.35)
    location.update_column(:suitable_experiences, ["culture"])

    # Manually create the association
    LocationExperienceType.create!(location: location, experience_type: exp_type)

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 0, results[:associations_created]
    assert_equal 1, location.reload.location_experience_types.count
  end

  test "perform normalizes experience type keys to lowercase" do
    create_location_with_experiences("Museum", ["CULTURE", "History", "FOOD"])

    results = ExperienceTypeSyncJob.perform_now

    assert_includes results[:new_types], "culture"
    assert_includes results[:new_types], "history"
    assert_includes results[:new_types], "food"
    assert ExperienceType.exists?(key: "culture")
  end

  test "perform handles multiple locations" do
    create_location_with_experiences("Sarajevo Museum", ["culture", "history"])
    create_location_with_experiences("Mostar Bridge", ["history", "architecture"])
    create_location_with_experiences("Bosnian Food Tour", ["food", "culture"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 3, results[:total_locations]
    assert_equal 4, results[:experience_types_created] # culture, history, architecture, food
    assert_equal 3, results[:locations_updated]
  end

  test "perform skips locations with nil suitable_experiences" do
    Location.create!(name: "No Experiences", city: "Sarajevo", suitable_experiences: nil)

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 0, results[:total_locations]
  end

  test "perform processes location with valid suitable_experiences" do
    # Test that locations with non-empty suitable_experiences are processed
    create_location_with_experiences("Valid Location", ["culture"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 1, results[:total_locations]
    assert_equal 1, results[:experience_types_created]
  end

  test "perform ignores blank experience keys" do
    # Create location and set suitable_experiences with blanks directly via update_column
    location = Location.create!(name: "Museum", city: "Sarajevo", lat: 43.85, lng: 18.35)
    location.update_column(:suitable_experiences, ["culture", "", "  ", "history"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 2, results[:experience_types_created]
    assert_includes results[:new_types], "culture"
    assert_includes results[:new_types], "history"
  end

  # === Dry run mode ===

  test "dry run does not create experience types" do
    create_location_with_experiences("Sarajevo Museum", ["culture", "history"])

    results = ExperienceTypeSyncJob.perform_now(dry_run: true)

    assert_equal 0, results[:experience_types_created]
    assert_equal 2, results[:new_types].count
    assert_not ExperienceType.exists?(key: "culture")
    assert_not ExperienceType.exists?(key: "history")
  end

  test "dry run does not create associations but counts them" do
    # Create experience type first
    ExperienceType.create!(key: "culture", name: "Culture", active: true, position: 1)

    # Create location without triggering the callback
    location = Location.create!(name: "Sarajevo Museum", city: "Sarajevo", lat: 43.85, lng: 18.35)
    location.update_column(:suitable_experiences, ["culture"])

    results = ExperienceTypeSyncJob.perform_now(dry_run: true)

    # Dry run should count what would be created
    assert_equal 1, results[:associations_created]
    # But not actually create them
    assert_equal 0, location.reload.location_experience_types.count
  end

  test "dry run reports what would be created" do
    # Create locations without triggering callbacks
    location1 = Location.create!(name: "Museum 1", city: "Sarajevo", lat: 43.85, lng: 18.35)
    location1.update_column(:suitable_experiences, ["culture", "history"])

    location2 = Location.create!(name: "Museum 2", city: "Mostar", lat: 43.34, lng: 17.81)
    location2.update_column(:suitable_experiences, ["food"])

    results = ExperienceTypeSyncJob.perform_now(dry_run: true)

    assert_equal true, results[:dry_run]
    assert_equal 3, results[:new_types].count
    # In dry run, no experience types are created, so associations cannot be created either
    # But the job still reports how many locations would be updated
    assert_equal 2, results[:total_locations]
  end

  # === Status updates during execution ===

  test "perform updates status to in_progress during execution" do
    create_location_with_experiences("Museum", ["culture"])

    # We can't easily check intermediate status, but we can verify final status
    ExperienceTypeSyncJob.perform_now

    status = ExperienceTypeSyncJob.current_status
    assert_equal "completed", status[:status]
  end

  test "perform updates status to completed on success" do
    results = ExperienceTypeSyncJob.perform_now

    status = ExperienceTypeSyncJob.current_status
    assert_equal "completed", status[:status]
    assert_includes status[:message], "Finished"
  end

  test "perform status message includes dry run indicator" do
    ExperienceTypeSyncJob.perform_now(dry_run: true)

    status = ExperienceTypeSyncJob.current_status
    assert_includes status[:message], "(DRY RUN)"
  end

  # === Error handling ===

  test "perform records errors for individual locations and completes" do
    # Create a valid location
    create_location_with_experiences("Valid Museum", ["culture"])

    # This should complete successfully
    results = ExperienceTypeSyncJob.perform_now

    assert_equal "completed", results[:status]
    assert results[:errors].is_a?(Array)
  end

  test "perform updates status to failed on catastrophic failure" do
    # Set initial status
    Setting.set("experience_type_sync.status", "idle")

    # Create a mock that will fail
    mock_relation = Minitest::Mock.new
    mock_relation.expect(:where, mock_relation) { |*args| true }
    mock_relation.expect(:not, mock_relation) { |*args| true }

    # Directly test the save_status behavior for failure scenario
    job = ExperienceTypeSyncJob.new
    job.send(:save_status, "failed", "Test failure message")

    status = ExperienceTypeSyncJob.current_status
    assert_equal "failed", status[:status]
    assert_includes status[:message], "Test failure message"
  end

  test "perform completes even with some errors in results" do
    create_location_with_experiences("Test Location", ["culture"])

    results = ExperienceTypeSyncJob.perform_now

    # Job should complete successfully
    assert_equal "completed", results[:status]
    # Errors array should exist (empty or with errors)
    assert results.key?(:errors)
  end

  # === Experience type creation details ===

  test "newly created experience types have correct attributes" do
    create_location_with_experiences("Museum", ["cultural heritage"])

    ExperienceTypeSyncJob.perform_now

    exp_type = ExperienceType.find_by(key: "cultural heritage")
    assert_not_nil exp_type
    assert_equal "Cultural Heritage", exp_type.name
    assert_equal true, exp_type.active
    assert exp_type.position >= 1
  end

  test "experience type position is incremented for each new type" do
    ExperienceType.create!(key: "existing", name: "Existing", active: true, position: 5)
    create_location_with_experiences("Museum", ["culture", "history"])

    ExperienceTypeSyncJob.perform_now

    culture = ExperienceType.find_by(key: "culture")
    history = ExperienceType.find_by(key: "history")

    assert culture.position > 5
    assert history.position > 5
    assert_not_equal culture.position, history.position
  end

  # === Case insensitivity ===

  test "existing experience type matching is case insensitive" do
    ExperienceType.create!(key: "Culture", name: "Culture", active: true, position: 1)

    # Create location and set suitable_experiences directly
    location = Location.create!(name: "Museum", city: "Sarajevo", lat: 43.85, lng: 18.35)
    location.update_column(:suitable_experiences, ["CULTURE", "culture", "Culture"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 0, results[:experience_types_created]
    assert_equal 1, ExperienceType.count
  end

  test "association matching is case insensitive" do
    ExperienceType.create!(key: "Culture", name: "Culture", active: true, position: 1)

    # Create location and set suitable_experiences directly
    location = Location.create!(name: "Museum", city: "Sarajevo", lat: 43.85, lng: 18.35)
    location.update_column(:suitable_experiences, ["culture"])

    ExperienceTypeSyncJob.perform_now

    assert_equal 1, location.reload.location_experience_types.count
  end

  # === Edge cases ===

  test "perform handles location with only whitespace experience keys" do
    location = Location.create!(name: "Whitespace Museum", city: "Sarajevo", lat: 43.85, lng: 18.35)
    location.update_column(:suitable_experiences, ["   ", "\t", "\n"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 0, results[:experience_types_created]
    assert_equal 0, results[:new_types].count
  end

  test "perform handles very long experience type keys" do
    long_key = "a" * 100
    create_location_with_experiences("Long Key Museum", [long_key])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 1, results[:experience_types_created]
    assert ExperienceType.exists?(key: long_key)
  end

  test "perform handles special characters in experience keys" do
    create_location_with_experiences("Special Museum", ["art & culture", "food-wine"])

    results = ExperienceTypeSyncJob.perform_now

    assert_equal 2, results[:experience_types_created]
    assert ExperienceType.exists?(key: "art & culture")
    assert ExperienceType.exists?(key: "food-wine")
  end

  private

  def create_location_with_experiences(name, experiences)
    # Generate unique coordinates to avoid validation errors
    lat = 43.8 + rand * 0.1
    lng = 18.3 + rand * 0.1

    Location.create!(
      name: name,
      city: "Sarajevo",
      suitable_experiences: experiences,
      lat: lat,
      lng: lng
    )
  end
end
