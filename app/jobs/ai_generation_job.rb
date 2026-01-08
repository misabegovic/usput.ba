# Background job for AI-powered experience generation
# Uses Solid Queue for job processing
class AiGenerationJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on GeoapifyService::ConfigurationError
  discard_on RubyLLM::ConfigurationError if defined?(RubyLLM::ConfigurationError)

  # @param city_name [String] The city name to generate experiences for
  # @param generation_type [String] Type of generation: "full", "locations_only", "experiences_only"
  # @param options [Hash] Additional options (lat, lng for coordinates)
  def perform(city_name, generation_type: "full", **options)
    # Create or find existing generation record
    generation = find_or_create_generation(city_name, generation_type)

    return if generation.completed? # Already done

    begin
      generation.start!

      # Get coordinates from options or from existing locations
      coordinates = resolve_coordinates(city_name, options)
      generator = Ai::ExperienceGenerator.new(city_name, coordinates: coordinates)

      result = case generation_type
      when "full"
        generator.generate_all
      when "locations_only"
        generator.generate_locations_only
      when "experiences_only"
        generator.generate_experiences_only
      else
        raise ArgumentError, "Unknown generation type: #{generation_type}"
      end

      generation.complete!(
        locations_count: result[:locations_created] || 0,
        experiences_count: result[:experiences_created] || 0,
        meta: {
          locations: result[:locations],
          experiences: result[:experiences]
        }
      )

      Rails.logger.info "[AiGenerationJob] Completed generation for #{city_name}: #{result}"

    rescue StandardError => e
      generation.fail!(e)
      Rails.logger.error "[AiGenerationJob] Failed generation for #{city_name}: #{e.message}"
      raise # Re-raise for retry mechanism
    end
  end

  private

  def find_or_create_generation(city_name, generation_type)
    # Check for existing pending/processing generation
    existing = AiGeneration.where(city_name: city_name, generation_type: generation_type)
                          .in_progress
                          .first

    return existing if existing

    # Create new generation record
    AiGeneration.create!(
      city_name: city_name,
      generation_type: generation_type,
      status: :pending
    )
  end

  # Resolve coordinates from options or existing locations
  def resolve_coordinates(city_name, options)
    # Use provided coordinates if available
    if options[:lat].present? && options[:lng].present?
      return { lat: options[:lat].to_f, lng: options[:lng].to_f }
    end

    # Try to get coordinates from existing locations in this city
    location = Location.where(city: city_name).where.not(lat: nil, lng: nil).first
    if location
      return { lat: location.lat, lng: location.lng }
    end

    # Fall back to geocoding the city name
    results = Geocoder.search("#{city_name}, Bosnia and Herzegovina")
    if results.first
      return { lat: results.first.latitude, lng: results.first.longitude }
    end

    raise ArgumentError, "Could not resolve coordinates for city: #{city_name}"
  end
end
