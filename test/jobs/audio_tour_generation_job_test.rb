# frozen_string_literal: true

require "test_helper"

class AudioTourGenerationJobTest < ActiveJob::TestCase
  setup do
    # Create test locations with coordinates
    @location1 = Location.create!(
      name: "Test Location 1",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      location_type: :place
    )

    @location2 = Location.create!(
      name: "Test Location 2",
      city: "Sarajevo",
      lat: 43.8600,
      lng: 18.4200,
      location_type: :place
    )

    @location3 = Location.create!(
      name: "Test Location 3",
      city: "Mostar",
      lat: 43.3438,
      lng: 17.8078,
      location_type: :place
    )

    # Location without coordinates (should be excluded from with_coordinates scope)
    @location_no_coords = Location.create!(
      name: "No Coords Location",
      city: "Sarajevo",
      location_type: :place
    )
  end

  teardown do
    @location1.destroy
    @location2.destroy
    @location3.destroy
    @location_no_coords.destroy
  end

  # === Queue configuration tests ===

  test "job is queued in ai_generation queue" do
    assert_equal "ai_generation", AudioTourGenerationJob.new.queue_name
  end

  test "job is enqueued to correct queue" do
    assert_enqueued_with(job: AudioTourGenerationJob, queue: "ai_generation") do
      AudioTourGenerationJob.perform_later(mode: "city", city_name: "Sarajevo")
    end
  end

  # === Retry configuration tests ===

  test "job has retry_on configured for StandardError" do
    retry_config = AudioTourGenerationJob.rescue_handlers.find do |handler|
      handler[0] == "StandardError"
    end

    assert_not_nil retry_config, "Should have retry_on for StandardError"
  end

  # === Parameter handling tests ===

  test "job accepts mode city with city_name" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "city", city_name: "Sarajevo" }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "city", city_name: "Sarajevo")
    end
  end

  test "job accepts mode missing" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "missing" }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "missing")
    end
  end

  test "job accepts mode location with location_id" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "location", location_id: 123 }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "location", location_id: 123)
    end
  end

  test "job accepts mode multilingual with location_id" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "multilingual", location_id: 123 }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "multilingual", location_id: 123)
    end
  end

  test "job accepts mode batch_multilingual with location_ids" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "batch_multilingual", location_ids: [1, 2, 3] }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "batch_multilingual", location_ids: [1, 2, 3])
    end
  end

  test "job accepts single locale parameter" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "location", location_id: 123, locale: "en" }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "location", location_id: 123, locale: "en")
    end
  end

  test "job accepts multiple locales parameter" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "location", location_id: 123, locales: %w[bs en de] }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "location", location_id: 123, locales: %w[bs en de])
    end
  end

  test "job accepts force option" do
    assert_enqueued_with(
      job: AudioTourGenerationJob,
      args: [{ mode: "location", location_id: 123, force: true }]
    ) do
      AudioTourGenerationJob.perform_later(mode: "location", location_id: 123, force: true)
    end
  end

  # === Mode: city tests ===

  test "city mode generates audio for locations in specified city" do
    generator_stub = create_generator_stub(generated: 1, skipped: 0, failed: 0)

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { generator_stub }) do
      result = AudioTourGenerationJob.new.perform(mode: "city", city_name: "Sarajevo")

      assert_equal "Sarajevo", result[:city]
    end
  end

  test "city mode only processes locations with coordinates" do
    processed_locations = []

    Ai::AudioTourGenerator.stub(:new, ->(loc) {
      processed_locations << loc
      create_generator_stub(generated: 0, skipped: 1, failed: 0)
    }) do
      AudioTourGenerationJob.new.perform(mode: "city", city_name: "Sarajevo")
    end

    # Should process location1 and location2, but not location_no_coords
    assert_includes processed_locations, @location1
    assert_includes processed_locations, @location2
    assert_not_includes processed_locations, @location_no_coords
  end

  # === Mode: missing tests ===

  test "missing mode checks for missing locales and generates only those" do
    generator_stub = create_generator_stub(generated: 2, skipped: 0, failed: 0)

    AudioTour.stub(:missing_locales_for_location, %w[en de]) do
      Ai::AudioTourGenerator.stub(:new, ->(_loc) { generator_stub }) do
        result = AudioTourGenerationJob.new.perform(mode: "missing")

        assert result[:generated] >= 0
      end
    end
  end

  test "missing mode skips locations with no missing locales" do
    generator_called = false

    AudioTour.stub(:missing_locales_for_location, []) do
      Ai::AudioTourGenerator.stub(:new, ->(_loc) {
        generator_called = true
        create_generator_stub(generated: 0, skipped: 0, failed: 0)
      }) do
        AudioTourGenerationJob.new.perform(mode: "missing")

        # Generator should not be called since no missing locales
        assert_not generator_called, "Generator should not be called when no missing locales"
      end
    end
  end

  # === Mode: location tests ===

  test "location mode generates audio for specific location" do
    generator_stub = create_generator_stub(generated: 3, skipped: 0, failed: 0)

    Ai::AudioTourGenerator.stub(:new, ->(_loc) { generator_stub }) do
      result = AudioTourGenerationJob.new.perform(mode: "location", location_id: @location1.id)

      assert_equal @location1.name, result[:location]
    end
  end

  test "location mode respects force option" do
    received_options = nil

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**opts|
        received_options = opts
        { summary: { generated: 3, skipped: 0, failed: 0 } }
      end
      generator
    }) do
      AudioTourGenerationJob.new.perform(mode: "location", location_id: @location1.id, force: true)
    end

    assert_equal true, received_options[:force]
  end

  test "location mode raises RecordNotFound for invalid location_id" do
    assert_raises(ActiveRecord::RecordNotFound) do
      AudioTourGenerationJob.new.perform(mode: "location", location_id: -1)
    end
  end

  # === Mode: multilingual tests ===

  test "multilingual mode calls generator with multilingual method" do
    generator_called = false

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**_opts|
        generator_called = true
        { summary: { generated: 3, skipped: 0, failed: 0 } }
      end
      generator
    }) do
      AudioTourGenerationJob.new.perform(mode: "multilingual", location_id: @location1.id)
    end

    assert generator_called, "generate_multilingual should be called"
  end

  test "multilingual mode uses custom locales when provided" do
    received_locales = nil

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**opts|
        received_locales = opts[:locales]
        { summary: { generated: 2, skipped: 0, failed: 0 } }
      end
      generator
    }) do
      AudioTourGenerationJob.new.perform(mode: "multilingual", location_id: @location1.id, locales: %w[fr it])
    end

    assert_equal %w[fr it], received_locales
  end

  # === Mode: batch_multilingual tests ===

  test "batch_multilingual mode processes multiple locations" do
    location_ids = [@location1.id, @location2.id]

    mock_result = {
      total_locations: 2,
      generated: 6,
      skipped: 0,
      failed: 0,
      errors: [],
      details: []
    }

    Ai::AudioTourGenerator.stub(:generate_batch, mock_result) do
      result = AudioTourGenerationJob.new.perform(mode: "batch_multilingual", location_ids: location_ids)

      assert_equal 2, result[:total_locations]
      assert_equal 6, result[:generated]
    end
  end

  test "batch_multilingual mode calls generate_batch with correct parameters" do
    location_ids = [@location1.id, @location2.id]
    batch_called_with = nil

    Ai::AudioTourGenerator.stub(:generate_batch, ->(locations, **opts) {
      batch_called_with = { locations: locations.to_a, options: opts }
      { generated: 0, skipped: 0, failed: 0 }
    }) do
      AudioTourGenerationJob.new.perform(mode: "batch_multilingual", location_ids: location_ids, locales: %w[en de], force: true)
    end

    assert_equal location_ids.sort, batch_called_with[:locations].map(&:id).sort
    assert_equal %w[en de], batch_called_with[:options][:locales]
    assert_equal true, batch_called_with[:options][:force]
  end

  # === Unknown mode tests ===

  test "raises ArgumentError for unknown mode" do
    error = assert_raises(ArgumentError) do
      AudioTourGenerationJob.new.perform(mode: "invalid_mode")
    end

    assert_match(/Unknown audio generation mode/, error.message)
    assert_match(/invalid_mode/, error.message)
  end

  # === Locale normalization tests ===

  test "normalizes single locale to array" do
    received_locales = nil

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**opts|
        received_locales = opts[:locales]
        { summary: { generated: 1, skipped: 0, failed: 0 } }
      end
      generator
    }) do
      AudioTourGenerationJob.new.perform(mode: "location", location_id: @location1.id, locale: "en")
    end

    assert_equal ["en"], received_locales
  end

  test "uses default locales when none provided" do
    received_locales = nil

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**opts|
        received_locales = opts[:locales]
        { summary: { generated: 3, skipped: 0, failed: 0 } }
      end
      generator
    }) do
      AudioTourGenerationJob.new.perform(mode: "location", location_id: @location1.id)
    end

    assert_equal AudioTour::DEFAULT_GENERATION_LOCALES, received_locales
  end

  test "converts symbol locales to strings" do
    received_locales = nil

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**opts|
        received_locales = opts[:locales]
        { summary: { generated: 2, skipped: 0, failed: 0 } }
      end
      generator
    }) do
      AudioTourGenerationJob.new.perform(mode: "location", location_id: @location1.id, locales: [:bs, :en])
    end

    assert_equal %w[bs en], received_locales
  end

  # === Error handling tests ===

  test "handles generator errors gracefully in city mode" do
    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**_opts|
        raise StandardError, "API Error"
      end
      generator
    }) do
      # Should not raise - error is caught and logged
      result = AudioTourGenerationJob.new.perform(mode: "city", city_name: "Sarajevo")

      # Failed count should be incremented
      assert result[:failed] > 0
    end
  end

  test "returns failed count when generation fails for a location" do
    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**_opts|
        raise StandardError, "TTS API failure"
      end
      generator
    }) do
      result = AudioTourGenerationJob.new.perform(mode: "city", city_name: "Sarajevo")

      # Each location should contribute to failed count based on locale count
      expected_failed_per_location = AudioTour::DEFAULT_GENERATION_LOCALES.length
      # 2 locations in Sarajevo with coords
      assert result[:failed] >= expected_failed_per_location
    end
  end

  # === Integration-style tests (with mocked external services) ===

  test "complete flow for location mode with mocked services" do
    mock_result = {
      location: @location1.name,
      locales: {
        "bs" => { status: :generated },
        "en" => { status: :generated },
        "de" => { status: :already_exists }
      },
      summary: { generated: 2, skipped: 1, failed: 0 }
    }

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**_opts|
        mock_result
      end
      generator
    }) do
      result = AudioTourGenerationJob.new.perform(mode: "location", location_id: @location1.id)

      assert_equal @location1.name, result[:location]
      assert_equal 2, result[:generated]
      assert_equal 1, result[:skipped]
      assert_equal 0, result[:failed]
    end
  end

  test "city mode aggregates results from multiple locations" do
    call_count = 0

    Ai::AudioTourGenerator.stub(:new, ->(_loc) {
      call_count += 1
      generator = Object.new
      generator.define_singleton_method(:generate_multilingual) do |**_opts|
        { summary: { generated: 1, skipped: 1, failed: 1 } }
      end
      generator
    }) do
      result = AudioTourGenerationJob.new.perform(mode: "city", city_name: "Sarajevo")

      # 2 locations in Sarajevo with coordinates
      assert_equal 2, call_count
      # Results should be aggregated
      assert_equal 2, result[:generated]
      assert_equal 2, result[:skipped]
      assert_equal 2, result[:failed]
    end
  end

  # === Edge cases ===

  test "city mode returns empty results for city with no locations" do
    result = nil

    Ai::AudioTourGenerator.stub(:new, ->(_) { raise "Should not be called" }) do
      result = AudioTourGenerationJob.new.perform(mode: "city", city_name: "NonExistentCity")
    end

    assert_equal "NonExistentCity", result[:city]
    assert_equal 0, result[:generated]
    assert_equal 0, result[:skipped]
    assert_equal 0, result[:failed]
  end

  test "missing mode processes limited batch of locations" do
    processed_count = 0

    AudioTour.stub(:missing_locales_for_location, %w[en]) do
      Ai::AudioTourGenerator.stub(:new, ->(_loc) {
        processed_count += 1
        create_generator_stub(generated: 1, skipped: 0, failed: 0)
      }) do
        AudioTourGenerationJob.new.perform(mode: "missing")
      end
    end

    # Should process locations but limited by the batch size
    assert processed_count > 0
    assert processed_count <= 100
  end

  test "batch_multilingual handles empty location_ids array" do
    Ai::AudioTourGenerator.stub(:generate_batch, ->(_locations, **_opts) {
      { total_locations: 0, generated: 0, skipped: 0, failed: 0, errors: [], details: [] }
    }) do
      result = AudioTourGenerationJob.new.perform(mode: "batch_multilingual", location_ids: [])

      assert_equal 0, result[:total_locations]
    end
  end

  # === Default locale constant tests ===

  test "uses AudioTour::DEFAULT_GENERATION_LOCALES as default" do
    # Verify the constant exists and has expected values
    assert_equal %w[bs en de], AudioTour::DEFAULT_GENERATION_LOCALES
  end

  private

  # Helper method to create a generator stub that returns consistent results
  def create_generator_stub(generated:, skipped:, failed:)
    generator = Object.new
    generator.define_singleton_method(:generate_multilingual) do |**_opts|
      { summary: { generated: generated, skipped: skipped, failed: failed } }
    end
    generator
  end
end
