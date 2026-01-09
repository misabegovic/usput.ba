# frozen_string_literal: true

require "test_helper"

class RegenerateTranslationsJobTest < ActiveSupport::TestCase
  setup do
    # Reset the job status before each test
    RegenerateTranslationsJob.reset_status!
  end

  teardown do
    RegenerateTranslationsJob.reset_status!
  end

  test "status is idle by default" do
    assert_equal "idle", RegenerateTranslationsJob.status
  end

  test "in_progress? returns false when idle" do
    assert_not RegenerateTranslationsJob.in_progress?
  end

  test "dirty_counts returns counts for all resource types" do
    counts = RegenerateTranslationsJob.dirty_counts

    assert counts.key?(:locations)
    assert counts.key?(:experiences)
    assert counts.key?(:plans)
  end

  test "progress returns empty hash by default" do
    progress = RegenerateTranslationsJob.progress

    assert_instance_of Hash, progress
  end

  test "dirty_counts includes resources with needs_ai_regeneration true" do
    # Create a location that needs regeneration
    location = Location.create!(
      name: "Dirty Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      needs_ai_regeneration: true
    )

    counts = RegenerateTranslationsJob.dirty_counts
    assert counts[:locations] >= 1

    # Cleanup
    location.destroy
  end

  test "reset_status! clears status back to idle" do
    Setting.set(RegenerateTranslationsJob::STATUS_KEY, "in_progress")

    RegenerateTranslationsJob.reset_status!

    assert_equal "idle", RegenerateTranslationsJob.status
  end
end
