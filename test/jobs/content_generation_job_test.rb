# frozen_string_literal: true

require "test_helper"

class ContentGenerationJobTest < ActiveJob::TestCase
  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", ContentGenerationJob.new.queue_name
  end

  test "job is enqueued to correct queue" do
    assert_enqueued_with(job: ContentGenerationJob, queue: "ai_generation") do
      ContentGenerationJob.perform_later
    end
  end

  # === Parameter handling tests ===

  test "job accepts max_locations parameter" do
    assert_enqueued_with(
      job: ContentGenerationJob,
      args: [{ max_locations: 25 }]
    ) do
      ContentGenerationJob.perform_later(max_locations: 25)
    end
  end

  test "job accepts max_experiences parameter" do
    assert_enqueued_with(
      job: ContentGenerationJob,
      args: [{ max_experiences: 50 }]
    ) do
      ContentGenerationJob.perform_later(max_experiences: 50)
    end
  end

  test "job accepts max_plans parameter" do
    assert_enqueued_with(
      job: ContentGenerationJob,
      args: [{ max_plans: 10 }]
    ) do
      ContentGenerationJob.perform_later(max_plans: 10)
    end
  end

  test "job accepts skip_locations parameter" do
    assert_enqueued_with(
      job: ContentGenerationJob,
      args: [{ skip_locations: true }]
    ) do
      ContentGenerationJob.perform_later(skip_locations: true)
    end
  end

  test "job accepts skip_experiences parameter" do
    assert_enqueued_with(
      job: ContentGenerationJob,
      args: [{ skip_experiences: true }]
    ) do
      ContentGenerationJob.perform_later(skip_experiences: true)
    end
  end

  test "job accepts skip_plans parameter" do
    assert_enqueued_with(
      job: ContentGenerationJob,
      args: [{ skip_plans: true }]
    ) do
      ContentGenerationJob.perform_later(skip_plans: true)
    end
  end

  test "job accepts all parameters together" do
    assert_enqueued_with(
      job: ContentGenerationJob,
      args: [{
        max_locations: 50,
        max_experiences: 100,
        max_plans: 25,
        skip_locations: true,
        skip_experiences: false,
        skip_plans: true
      }]
    ) do
      ContentGenerationJob.perform_later(
        max_locations: 50,
        max_experiences: 100,
        max_plans: 25,
        skip_locations: true,
        skip_experiences: false,
        skip_plans: true
      )
    end
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = ContentGenerationJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  test "job discards on GeoapifyService::ConfigurationError" do
    discard_config = ContentGenerationJob.rescue_handlers.find do |handler|
      handler[0] == "GeoapifyService::ConfigurationError"
    end

    assert_not_nil discard_config, "Should have discard_on for GeoapifyService::ConfigurationError"
  end

  test "job discards on ContentOrchestrator::GenerationError" do
    discard_config = ContentGenerationJob.rescue_handlers.find do |handler|
      handler[0] == "Ai::ContentOrchestrator::GenerationError"
    end

    assert_not_nil discard_config, "Should have discard_on for GenerationError"
  end
end
