# frozen_string_literal: true

require "test_helper"

class AiGenerationJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", AiGenerationJob.new.queue_name
  end

  test "job is enqueued to correct queue" do
    assert_enqueued_with(job: AiGenerationJob, queue: "ai_generation") do
      AiGenerationJob.perform_later("Sarajevo")
    end
  end

  # === Parameter handling tests ===

  test "job accepts city_name parameter" do
    assert_enqueued_with(job: AiGenerationJob, args: ["Sarajevo"]) do
      AiGenerationJob.perform_later("Sarajevo")
    end
  end

  test "job accepts generation_type option" do
    assert_enqueued_with(
      job: AiGenerationJob,
      args: ["Mostar", { generation_type: "locations_only" }]
    ) do
      AiGenerationJob.perform_later("Mostar", generation_type: "locations_only")
    end
  end

  test "job accepts coordinate options" do
    assert_enqueued_with(
      job: AiGenerationJob,
      args: ["Banja Luka", { lat: 44.7758, lng: 17.1858 }]
    ) do
      AiGenerationJob.perform_later("Banja Luka", lat: 44.7758, lng: 17.1858)
    end
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = AiGenerationJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  test "job discards on GeoapifyService::ConfigurationError" do
    discard_config = AiGenerationJob.rescue_handlers.find do |handler|
      handler[0] == "GeoapifyService::ConfigurationError"
    end

    assert_not_nil discard_config, "Should have discard_on for GeoapifyService::ConfigurationError"
  end
end
