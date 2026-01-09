# frozen_string_literal: true

require "test_helper"

class RebuildPlansJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", RebuildPlansJob.new.queue_name
  end

  test "job is enqueued with parameters" do
    assert_enqueued_with(
      job: RebuildPlansJob,
      args: [{ dry_run: true, rebuild_mode: "quality", max_rebuilds: 10 }]
    ) do
      RebuildPlansJob.perform_later(dry_run: true, rebuild_mode: "quality", max_rebuilds: 10)
    end
  end

  # === Constants tests ===

  test "EXPERIENCE_REBUILD_THRESHOLD is defined" do
    assert_equal 50, RebuildPlansJob::EXPERIENCE_REBUILD_THRESHOLD
  end

  test "MODES includes all valid modes" do
    assert_includes RebuildPlansJob::MODES, "all"
    assert_includes RebuildPlansJob::MODES, "quality"
    assert_includes RebuildPlansJob::MODES, "similar"
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = RebuildPlansJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end
end
