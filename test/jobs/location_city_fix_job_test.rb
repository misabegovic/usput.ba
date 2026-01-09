# frozen_string_literal: true

require "test_helper"

class LocationCityFixJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in default queue" do
    assert_equal "default", LocationCityFixJob.new.queue_name
  end

  test "job is enqueued with parameters" do
    assert_enqueued_with(
      job: LocationCityFixJob,
      args: [{ regenerate_content: true, dry_run: false }]
    ) do
      LocationCityFixJob.perform_later(regenerate_content: true, dry_run: false)
    end
  end

  # === Rate limit constants tests ===

  test "GEOAPIFY_SLEEP is defined as 0.2 seconds" do
    assert_equal 0.2, LocationCityFixJob::GEOAPIFY_SLEEP
  end

  test "NOMINATIM_SLEEP is defined as 1.1 seconds" do
    assert_equal 1.1, LocationCityFixJob::NOMINATIM_SLEEP
  end

  test "GEOAPIFY_SLEEP is faster than NOMINATIM_SLEEP" do
    assert LocationCityFixJob::GEOAPIFY_SLEEP < LocationCityFixJob::NOMINATIM_SLEEP
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = LocationCityFixJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = LocationCityFixJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "clear_status! resets status to idle" do
    Setting.set("location_fix.status", "in_progress")
    Setting.set("location_fix.message", "Working...")

    LocationCityFixJob.clear_status!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
    # Message is cleared to empty string or nil
    assert_includes [nil, ""], status[:message]
  end

  test "force_reset_city_fix! resets stuck job" do
    Setting.set("location_fix.status", "in_progress")

    LocationCityFixJob.force_reset_city_fix!

    status = LocationCityFixJob.current_status
    assert_equal "idle", status[:status]
  end
end
