# Background job for generating audio tours for locations
# Supports multilingual audio tour generation
class AudioTourGenerationJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # @param mode [String] Generation mode: "city", "missing", "location", "multilingual"
  # @param locale [String] Single language code (for backwards compatibility)
  # @param locales [Array<String>] Multiple language codes for multilingual mode
  # @param options [Hash] Additional options depending on mode
  def perform(mode:, locale: nil, locales: nil, **options)
    # Handle both single locale and multiple locales
    @locales = normalize_locales(locale, locales)
    @force = options.fetch(:force, false)

    case mode
    when "city"
      generate_for_city(options[:city_name])
    when "missing"
      generate_for_missing
    when "location"
      generate_for_location(options[:location_id])
    when "multilingual"
      generate_multilingual_for_location(options[:location_id])
    when "batch_multilingual"
      generate_batch_multilingual(options[:location_ids])
    else
      raise ArgumentError, "Unknown audio generation mode: #{mode}"
    end
  end

  private

  def normalize_locales(locale, locales)
    if locales.present?
      Array(locales).map(&:to_s)
    elsif locale.present?
      [locale.to_s]
    else
      AudioTour::DEFAULT_GENERATION_LOCALES
    end
  end

  def generate_for_city(city_name)
    locations = Location.where(city: city_name).with_coordinates

    Rails.logger.info "[AudioTourGenerationJob] Starting multilingual audio generation for #{locations.count} locations in #{city_name}"
    Rails.logger.info "[AudioTourGenerationJob] Target languages: #{@locales.join(', ')}"

    results = { generated: 0, skipped: 0, failed: 0, by_locale: {} }

    locations.find_each do |location|
      location_result = generate_multilingual_audio_for_location(location)
      results[:generated] += location_result[:generated]
      results[:skipped] += location_result[:skipped]
      results[:failed] += location_result[:failed]
    end

    Rails.logger.info "[AudioTourGenerationJob] Completed for #{city_name}: #{results}"
    results.merge(city: city_name)
  end

  def generate_for_missing
    # Find locations that are missing audio tours for any of the target locales
    Rails.logger.info "[AudioTourGenerationJob] Finding locations missing audio tours for: #{@locales.join(', ')}"

    locations = Location.with_coordinates.limit(100) # Process in batches

    results = { generated: 0, skipped: 0, failed: 0 }

    locations.find_each do |location|
      # Only generate for locales that are missing
      missing_locales = AudioTour.missing_locales_for_location(location, target_locales: @locales)
      next if missing_locales.empty?

      location_result = generate_multilingual_audio_for_location(location, locales: missing_locales)
      results[:generated] += location_result[:generated]
      results[:skipped] += location_result[:skipped]
      results[:failed] += location_result[:failed]
    end

    Rails.logger.info "[AudioTourGenerationJob] Generated #{results[:generated]} audio tours for missing locales"
    results
  end

  def generate_for_location(location_id)
    location = Location.find(location_id)

    Rails.logger.info "[AudioTourGenerationJob] Generating audio for #{location.name} in #{@locales.join(', ')}"

    result = generate_multilingual_audio_for_location(location, force: @force)

    Rails.logger.info "[AudioTourGenerationJob] Completed for #{location.name}: generated=#{result[:generated]}, skipped=#{result[:skipped]}, failed=#{result[:failed]}"
    result.merge(location: location.name)
  end

  def generate_multilingual_for_location(location_id)
    location = Location.find(location_id)

    Rails.logger.info "[AudioTourGenerationJob] Generating multilingual audio for #{location.name}"

    generator = Ai::AudioTourGenerator.new(location)
    result = generator.generate_multilingual(locales: @locales, force: @force)

    Rails.logger.info "[AudioTourGenerationJob] Multilingual generation complete for #{location.name}: #{result[:summary]}"
    result
  end

  def generate_batch_multilingual(location_ids)
    locations = Location.where(id: location_ids)

    Rails.logger.info "[AudioTourGenerationJob] Batch multilingual generation for #{locations.count} locations in #{@locales.join(', ')}"

    result = Ai::AudioTourGenerator.generate_batch(locations, locales: @locales, force: @force)

    Rails.logger.info "[AudioTourGenerationJob] Batch complete: generated=#{result[:generated]}, skipped=#{result[:skipped]}, failed=#{result[:failed]}"
    result
  end

  def generate_multilingual_audio_for_location(location, locales: nil, force: nil)
    target_locales = locales || @locales
    force_regenerate = force.nil? ? @force : force

    generator = Ai::AudioTourGenerator.new(location)
    result = generator.generate_multilingual(locales: target_locales, force: force_regenerate)

    result[:summary]
  rescue StandardError => e
    Rails.logger.error "[AudioTourGenerationJob] Error generating audio for #{location.name}: #{e.message}"
    { generated: 0, skipped: 0, failed: target_locales.length }
  end
end
