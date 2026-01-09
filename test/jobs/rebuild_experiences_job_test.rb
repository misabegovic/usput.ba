# frozen_string_literal: true

require "test_helper"

class RebuildExperiencesJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", RebuildExperiencesJob.new.queue_name
  end

  test "job is enqueued with parameters" do
    assert_enqueued_with(
      job: RebuildExperiencesJob,
      args: [{ dry_run: true, rebuild_mode: "quality", max_rebuilds: 10 }]
    ) do
      RebuildExperiencesJob.perform_later(dry_run: true, rebuild_mode: "quality", max_rebuilds: 10)
    end
  end

  # === Constants tests ===

  test "MODES includes all valid modes" do
    assert_includes RebuildExperiencesJob::MODES, "all"
    assert_includes RebuildExperiencesJob::MODES, "quality"
    assert_includes RebuildExperiencesJob::MODES, "similar"
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = RebuildExperiencesJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  # === Status methods tests ===

  test "current_status returns hash with expected keys" do
    status = RebuildExperiencesJob.current_status

    assert status.is_a?(Hash)
    assert_includes status.keys, :status
    assert_includes status.keys, :message
    assert_includes status.keys, :results
  end

  test "clear_status! resets status to idle" do
    Setting.set("rebuild_experiences.status", "in_progress")
    Setting.set("rebuild_experiences.message", "Working...")

    RebuildExperiencesJob.clear_status!

    status = RebuildExperiencesJob.current_status
    assert_equal "idle", status[:status]
  end

  test "force_reset! resets stuck job" do
    Setting.set("rebuild_experiences.status", "in_progress")

    RebuildExperiencesJob.force_reset!

    status = RebuildExperiencesJob.current_status
    assert_equal "idle", status[:status]
  end
end
