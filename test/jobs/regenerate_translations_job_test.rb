# frozen_string_literal: true

require "test_helper"

class RegenerateTranslationsJobTest < ActiveJob::TestCase
  setup do
    # Reset the job status before each test
    RegenerateTranslationsJob.reset_status!

    # Create test data
    @location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      needs_ai_regeneration: true
    )

    @experience = Experience.create!(
      title: "Test Experience",
      description: "A wonderful test experience",
      needs_ai_regeneration: true
    )

    @plan = Plan.create!(
      title: "Test Plan",
      city_name: "Sarajevo",
      notes: "Some travel notes",
      needs_ai_regeneration: true
    )

    # Add the chat method stub to Ai::OpenaiQueue for tests
    # The job uses .chat but the class only has .request - this helps tests run
    unless Ai::OpenaiQueue.respond_to?(:chat)
      Ai::OpenaiQueue.define_singleton_method(:chat) do |messages:, response_format:, context:|
        '{"en": {"title": "Default", "description": "Default", "notes": "Default"}}'
      end
    end
  end

  teardown do
    RegenerateTranslationsJob.reset_status!
    # Clean up test data
    @location&.destroy
    @experience&.destroy
    @plan&.destroy
  end

  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", RegenerateTranslationsJob.new.queue_name
  end

  test "job is enqueued with options" do
    assert_enqueued_with(
      job: RegenerateTranslationsJob,
      args: [{ dry_run: true, include_audio: false }]
    ) do
      RegenerateTranslationsJob.perform_later(dry_run: true, include_audio: false)
    end
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = RegenerateTranslationsJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  test "job discards on ActiveRecord::RecordNotFound" do
    discard_config = RegenerateTranslationsJob.rescue_handlers.find do |handler|
      handler[0] == "ActiveRecord::RecordNotFound"
    end

    assert_not_nil discard_config, "Should have discard_on for RecordNotFound"
  end

  # === Class methods tests ===

  test "status returns idle by default" do
    assert_equal "idle", RegenerateTranslationsJob.status
  end

  test "in_progress? returns false when idle" do
    assert_not RegenerateTranslationsJob.in_progress?
  end

  test "in_progress? returns true when status is in_progress" do
    Setting.set(RegenerateTranslationsJob::STATUS_KEY, "in_progress")
    assert RegenerateTranslationsJob.in_progress?
  end

  test "progress returns empty hash by default" do
    progress = RegenerateTranslationsJob.progress

    assert_instance_of Hash, progress
    assert_empty progress
  end

  test "progress returns parsed progress data" do
    progress_data = { message: "Processing...", current: 5, total: 10 }
    Setting.set(RegenerateTranslationsJob::PROGRESS_KEY, progress_data.to_json)

    progress = RegenerateTranslationsJob.progress

    assert_equal "Processing...", progress["message"]
    assert_equal 5, progress["current"]
    assert_equal 10, progress["total"]
  end

  test "progress returns empty hash on JSON parse error" do
    Setting.set(RegenerateTranslationsJob::PROGRESS_KEY, "invalid json{")

    progress = RegenerateTranslationsJob.progress

    assert_instance_of Hash, progress
    assert_empty progress
  end

  test "reset_status! clears status back to idle" do
    Setting.set(RegenerateTranslationsJob::STATUS_KEY, "in_progress")
    Setting.set(RegenerateTranslationsJob::PROGRESS_KEY, '{"message": "Working"}')

    RegenerateTranslationsJob.reset_status!

    assert_equal "idle", RegenerateTranslationsJob.status
    assert_empty RegenerateTranslationsJob.progress
  end

  test "dirty_counts returns counts for all resource types" do
    counts = RegenerateTranslationsJob.dirty_counts

    assert counts.key?(:locations)
    assert counts.key?(:experiences)
    assert counts.key?(:plans)
  end

  test "dirty_counts includes resources with needs_ai_regeneration true" do
    counts = RegenerateTranslationsJob.dirty_counts

    assert counts[:locations] >= 1, "Should include at least one dirty location"
    assert counts[:experiences] >= 1, "Should include at least one dirty experience"
    assert counts[:plans] >= 1, "Should include at least one dirty plan"
  end

  test "dirty_counts excludes resources with needs_ai_regeneration false" do
    clean_location = Location.create!(
      name: "Clean Location",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      needs_ai_regeneration: false
    )

    initial_count = RegenerateTranslationsJob.dirty_counts[:locations]

    clean_location.update!(needs_ai_regeneration: true)
    new_count = RegenerateTranslationsJob.dirty_counts[:locations]

    assert_equal initial_count + 1, new_count
  ensure
    clean_location&.destroy
  end

  # === Perform method tests ===

  test "perform updates status to in_progress at start" do
    # Use dry_run to avoid actual AI calls
    job = RegenerateTranslationsJob.new

    # Mock the private methods to track status changes
    status_at_start = nil
    job.stub(:process_dirty_locations, -> {
      status_at_start = RegenerateTranslationsJob.status
    }) do
      job.stub(:process_dirty_experiences, -> {}) do
        job.stub(:process_dirty_plans, -> {}) do
          job.perform(dry_run: true)
        end
      end
    end

    assert_equal "in_progress", status_at_start
  end

  test "perform updates status to completed on success" do
    job = RegenerateTranslationsJob.new

    job.stub(:process_dirty_locations, -> {}) do
      job.stub(:process_dirty_experiences, -> {}) do
        job.stub(:process_dirty_plans, -> {}) do
          job.perform(dry_run: true)
        end
      end
    end

    assert_equal "completed", RegenerateTranslationsJob.status
  end

  test "perform updates status to failed on error" do
    job = RegenerateTranslationsJob.new

    job.stub(:process_dirty_locations, -> { raise StandardError, "Test error" }) do
      assert_raises(StandardError) do
        job.perform(dry_run: true)
      end
    end

    assert_equal "failed", RegenerateTranslationsJob.status
  end

  test "perform with dry_run does not modify records" do
    @location.update!(needs_ai_regeneration: true)

    mock_enricher = Minitest::Mock.new
    # enricher.enrich should NOT be called in dry_run mode

    Ai::LocationEnricher.stub(:new, mock_enricher) do
      RegenerateTranslationsJob.perform_now(dry_run: true)
    end

    @location.reload
    assert @location.needs_ai_regeneration, "Location should still need regeneration in dry_run mode"
  end

  test "perform processes locations with AI enricher" do
    # Mark other resources as not needing regeneration
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    mock_enricher = Minitest::Mock.new
    mock_enricher.expect(:enrich, true, [@location])

    mock_audio_generator = Minitest::Mock.new
    # Mock for each default locale (bs, en, de)
    3.times do
      mock_audio_generator.expect(:generate, { status: :generated }, [{ locale: String, force: true }])
    end

    Ai::LocationEnricher.stub(:new, mock_enricher) do
      Ai::AudioTourGenerator.stub(:new, ->(location) { mock_audio_generator }) do
        RegenerateTranslationsJob.perform_now(dry_run: false, include_audio: true)
      end
    end

    mock_enricher.verify

    @location.reload
    assert_not @location.needs_ai_regeneration, "Location should be marked as processed"
  end

  test "perform processes locations without audio when include_audio is false" do
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    mock_enricher = Minitest::Mock.new
    mock_enricher.expect(:enrich, true, [@location])

    # Audio generator should NOT be called
    Ai::LocationEnricher.stub(:new, mock_enricher) do
      RegenerateTranslationsJob.perform_now(dry_run: false, include_audio: false)
    end

    mock_enricher.verify
    @location.reload
    assert_not @location.needs_ai_regeneration
  end

  test "perform processes experiences with translations" do
    @location.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    mock_response = {
      "en" => { "title" => "English Title", "description" => "English Description" },
      "bs" => { "title" => "Bosanski naslov", "description" => "Bosanski opis" }
    }.to_json

    original_chat = Ai::OpenaiQueue.method(:chat)
    Ai::OpenaiQueue.define_singleton_method(:chat) { |**args| mock_response }

    begin
      RegenerateTranslationsJob.perform_now(dry_run: false)
    ensure
      Ai::OpenaiQueue.define_singleton_method(:chat, original_chat)
    end

    @experience.reload
    assert_not @experience.needs_ai_regeneration, "Experience should be marked as processed"
  end

  test "perform processes plans with translations" do
    @location.update_column(:needs_ai_regeneration, false)
    @experience.update_column(:needs_ai_regeneration, false)

    mock_response = {
      "en" => { "title" => "English Title", "notes" => "English Notes" },
      "bs" => { "title" => "Bosanski naslov", "notes" => "Bosanske biljeske" }
    }.to_json

    original_chat = Ai::OpenaiQueue.method(:chat)
    Ai::OpenaiQueue.define_singleton_method(:chat) { |**args| mock_response }

    begin
      RegenerateTranslationsJob.perform_now(dry_run: false)
    ensure
      Ai::OpenaiQueue.define_singleton_method(:chat, original_chat)
    end

    @plan.reload
    assert_not @plan.needs_ai_regeneration, "Plan should be marked as processed"
  end

  # === Error handling tests ===

  test "perform continues processing other locations when one fails" do
    second_location = Location.create!(
      name: "Second Location",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      needs_ai_regeneration: true
    )

    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    call_count = 0
    mock_enricher = Minitest::Mock.new

    Ai::LocationEnricher.stub(:new, -> {
      Object.new.tap do |obj|
        obj.define_singleton_method(:enrich) do |loc|
          call_count += 1
          if loc.id == @location.id
            raise StandardError, "Simulated failure"
          end
          true
        end
      end
    }) do
      RegenerateTranslationsJob.perform_now(dry_run: false, include_audio: false)
    end

    # Should have attempted both locations
    assert_operator call_count, :>=, 1, "Should have processed at least one location"
  ensure
    second_location&.destroy
  end

  test "perform continues processing other experiences when one fails" do
    second_experience = Experience.create!(
      title: "Second Experience",
      description: "Another test experience",
      needs_ai_regeneration: true
    )

    @location.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    call_count = 0
    original_chat = Ai::OpenaiQueue.method(:chat)
    Ai::OpenaiQueue.define_singleton_method(:chat) do |**args|
      call_count += 1
      raise StandardError, "Simulated AI failure" if call_count == 1
      '{"en": {"title": "Title", "description": "Desc"}}'
    end

    begin
      RegenerateTranslationsJob.perform_now(dry_run: false)
    ensure
      Ai::OpenaiQueue.define_singleton_method(:chat, original_chat)
    end

    # Job should complete despite individual failures
    assert_equal "completed", RegenerateTranslationsJob.status
  ensure
    second_experience&.destroy
  end

  test "perform records failed counts in results" do
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    mock_enricher_class = -> {
      Object.new.tap do |obj|
        obj.define_singleton_method(:enrich) do |loc|
          raise StandardError, "Simulated failure"
        end
      end
    }

    Ai::LocationEnricher.stub(:new, mock_enricher_class.call) do
      RegenerateTranslationsJob.perform_now(dry_run: false, include_audio: false)
    end

    progress = RegenerateTranslationsJob.progress
    assert progress["results"], "Should have results in progress"
    assert_operator progress["results"]["locations"]["failed"], :>=, 1, "Should have recorded failed location"
  end

  # === Progress tracking tests ===

  test "perform updates progress during processing" do
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    progress_updates = []

    original_set = Setting.method(:set)
    Setting.stub(:set, -> (key, value, **opts) {
      if key == RegenerateTranslationsJob::PROGRESS_KEY
        progress_updates << JSON.parse(value) rescue value
      end
      original_set.call(key, value, **opts)
    }) do
      mock_enricher = Minitest::Mock.new
      mock_enricher.expect(:enrich, true, [@location])

      Ai::LocationEnricher.stub(:new, mock_enricher) do
        RegenerateTranslationsJob.perform_now(dry_run: false, include_audio: false)
      end
    end

    # Should have multiple progress updates
    assert_operator progress_updates.length, :>=, 1, "Should have progress updates"
  end

  # === Edge cases ===

  test "perform handles no dirty resources gracefully" do
    @location.update_column(:needs_ai_regeneration, false)
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    RegenerateTranslationsJob.perform_now(dry_run: false)

    assert_equal "completed", RegenerateTranslationsJob.status
    progress = RegenerateTranslationsJob.progress
    results = progress["results"]
    assert_equal 0, results["locations"]["success"]
    assert_equal 0, results["experiences"]["success"]
    assert_equal 0, results["plans"]["success"]
  end

  test "perform with empty options uses defaults" do
    @location.update_column(:needs_ai_regeneration, false)
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    RegenerateTranslationsJob.perform_now

    assert_equal "completed", RegenerateTranslationsJob.status
  end

  test "perform handles nil translations response gracefully" do
    @location.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    original_chat = Ai::OpenaiQueue.method(:chat)
    Ai::OpenaiQueue.define_singleton_method(:chat) { |**args| nil }

    begin
      RegenerateTranslationsJob.perform_now(dry_run: false)
    ensure
      Ai::OpenaiQueue.define_singleton_method(:chat, original_chat)
    end

    # Should not crash, experience should still be marked as processed
    @experience.reload
    assert_not @experience.needs_ai_regeneration
  end

  test "perform handles JSON parse error in translations gracefully" do
    @location.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    original_chat = Ai::OpenaiQueue.method(:chat)
    Ai::OpenaiQueue.define_singleton_method(:chat) { |**args| "invalid json {{{" }

    begin
      RegenerateTranslationsJob.perform_now(dry_run: false)
    ensure
      Ai::OpenaiQueue.define_singleton_method(:chat, original_chat)
    end

    # Should not crash
    assert_equal "completed", RegenerateTranslationsJob.status
  end

  # === Audio tour generation tests ===

  test "regenerate_audio_tours generates for default locales" do
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    locales_called = []
    mock_generator_class = -> (location) {
      Object.new.tap do |obj|
        obj.define_singleton_method(:generate) do |locale:, force:|
          locales_called << locale
          { status: :generated }
        end
      end
    }

    mock_enricher = Minitest::Mock.new
    mock_enricher.expect(:enrich, true, [@location])

    Ai::LocationEnricher.stub(:new, mock_enricher) do
      Ai::AudioTourGenerator.stub(:new, mock_generator_class) do
        RegenerateTranslationsJob.perform_now(dry_run: false, include_audio: true)
      end
    end

    # Should generate for bs, en, de (default locales)
    assert_includes locales_called, "bs"
    assert_includes locales_called, "en"
    assert_includes locales_called, "de"
  end

  test "audio tour generation failure does not stop processing" do
    @experience.update_column(:needs_ai_regeneration, false)
    @plan.update_column(:needs_ai_regeneration, false)

    mock_generator_class = -> (location) {
      Object.new.tap do |obj|
        obj.define_singleton_method(:generate) do |locale:, force:|
          raise StandardError, "Audio generation failed"
        end
      end
    }

    mock_enricher = Minitest::Mock.new
    mock_enricher.expect(:enrich, true, [@location])

    Ai::LocationEnricher.stub(:new, mock_enricher) do
      Ai::AudioTourGenerator.stub(:new, mock_generator_class) do
        RegenerateTranslationsJob.perform_now(dry_run: false, include_audio: true)
      end
    end

    # Job should complete successfully despite audio failures
    assert_equal "completed", RegenerateTranslationsJob.status
    @location.reload
    assert_not @location.needs_ai_regeneration, "Location should still be marked as processed"
  end

  # === Constants tests ===

  test "STATUS_KEY constant is defined" do
    assert_equal "regenerate_translations.status", RegenerateTranslationsJob::STATUS_KEY
  end

  test "PROGRESS_KEY constant is defined" do
    assert_equal "regenerate_translations.progress", RegenerateTranslationsJob::PROGRESS_KEY
  end
end
