# frozen_string_literal: true

# Background job for fixing location cities using reverse geocoding
# and regenerating descriptions where city was corrected or quality is poor
#
# Usage:
#   LocationCityFixJob.perform_later
#   LocationCityFixJob.perform_later(regenerate_content: true)
#   LocationCityFixJob.perform_later(analyze_descriptions: true) # Analyze and regenerate poor descriptions
#   LocationCityFixJob.perform_later(dry_run: true) # Preview changes without saving
#   LocationCityFixJob.perform_later(clear_cache: true) # Clear geocoder cache first
class LocationCityFixJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Rate limits per service (seconds between requests)
  GEOAPIFY_SLEEP = 0.2   # 5 requests/second
  NOMINATIM_SLEEP = 1.1  # 1 request/second (with small buffer)

  def perform(regenerate_content: false, analyze_descriptions: false, dry_run: false, clear_cache: false)
    Rails.logger.info "[LocationCityFixJob] Starting location city fix (regenerate_content: #{regenerate_content}, analyze_descriptions: #{analyze_descriptions}, dry_run: #{dry_run}, clear_cache: #{clear_cache})"

    save_status("in_progress", "Starting location city fix...")

    # Clear geocoder cache if requested (useful for getting fresh results)
    if clear_cache
      Rails.logger.info "[LocationCityFixJob] Clearing geocoder cache..."
      clear_geocoder_cache!
    end

    results = {
      started_at: Time.current,
      total_checked: 0,
      cities_corrected: 0,
      content_regenerated: 0,
      descriptions_analyzed: 0,
      descriptions_regenerated: 0,
      errors: [],
      corrections: [],
      description_issues: []
    }

    begin
      locations = Location.with_coordinates.includes(:translations)

      locations.find_each(batch_size: 50) do |location|
        results[:total_checked] += 1

        begin
          geocode_source = process_location(location, results,
                                            regenerate_content: regenerate_content,
                                            analyze_descriptions: analyze_descriptions,
                                            dry_run: dry_run)

          # Rate limit based on which geocoding service was used
          case geocode_source
          when :nominatim
            sleep(NOMINATIM_SLEEP)
          when :geoapify
            sleep(GEOAPIFY_SLEEP)
          # :override and nil don't need rate limiting
          end
        rescue StandardError => e
          results[:errors] << { location_id: location.id, name: location.name, error: e.message }
          Rails.logger.warn "[LocationCityFixJob] Error processing #{location.name}: #{e.message}"
        end

        # Update status periodically
        if results[:total_checked] % 10 == 0
          save_status("in_progress", "Processed #{results[:total_checked]} locations... (#{results[:cities_corrected]} corrected, #{results[:descriptions_regenerated]} descriptions regenerated)")
        end
      end

      results[:finished_at] = Time.current
      results[:status] = "completed"

      summary = build_completion_summary(results)
      save_status("completed", summary, results: results)

      Rails.logger.info "[LocationCityFixJob] Completed: #{results}"
      results

    rescue StandardError => e
      results[:status] = "failed"
      results[:error] = e.message
      save_status("failed", e.message, results: results)
      Rails.logger.error "[LocationCityFixJob] Failed: #{e.message}"
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("location_fix.status", default: "idle"),
      message: Setting.get("location_fix.message", default: nil),
      results: JSON.parse(Setting.get("location_fix.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("location_fix.status", "idle")
    Setting.set("location_fix.message", nil)
    Setting.set("location_fix.results", "{}")
  end

  # Force reset a stuck or in-progress job back to idle
  def self.force_reset_city_fix!
    Setting.set("location_fix.status", "idle")
    Setting.set("location_fix.message", "Force reset by admin")
  end

  private

  # Returns the geocoding source used (:geoapify, :nominatim, :override, or nil)
  def process_location(location, results, regenerate_content:, analyze_descriptions:, dry_run:)
    city_corrected = false
    correct_city = location.city

    # Get the correct city from coordinates
    geocode_result = get_city_from_coordinates(location.lat, location.lng)
    geocoded_city = geocode_result[:city]
    geocode_source = geocode_result[:source]

    if geocoded_city.present?
      # Compare with current city
      current_city = location.city.to_s.strip
      needs_correction = cities_different?(current_city, geocoded_city)

      if needs_correction
        Rails.logger.info "[LocationCityFixJob] City correction needed for '#{location.name}': '#{current_city}' -> '#{geocoded_city}'"

        results[:corrections] << {
          location_id: location.id,
          name: location.name,
          old_city: current_city,
          new_city: geocoded_city
        }

        unless dry_run
          # Update the city
          location.city = geocoded_city
          location.save!
          results[:cities_corrected] += 1
          city_corrected = true
          correct_city = geocoded_city
        end
      end
    end

    # Handle content regeneration based on city correction
    if city_corrected && regenerate_content && !dry_run
      regenerate_location_content(location, correct_city)
      results[:content_regenerated] += 1
    end

    # Analyze descriptions if requested (independent of city correction)
    if analyze_descriptions
      analyze_and_regenerate_description(location, results, dry_run: dry_run, city: correct_city)
    end

    geocode_source
  end

  def analyze_and_regenerate_description(location, results, dry_run:, city:)
    analyzer = Ai::LocationAnalyzer.new
    analysis = analyzer.analyze(location)

    results[:descriptions_analyzed] += 1

    return unless analysis[:needs_regeneration]

    Rails.logger.info "[LocationCityFixJob] Description regeneration needed for '#{location.name}' (score: #{analysis[:score]})"

    results[:description_issues] << {
      location_id: location.id,
      name: location.name,
      city: location.city,
      score: analysis[:score],
      issues: analysis[:issues].map { |i| { type: i[:type], message: i[:message], locale: i[:locale] } }
    }

    unless dry_run
      regenerate_location_content(location, city)
      results[:descriptions_regenerated] += 1
      Rails.logger.info "[LocationCityFixJob] Regenerated description for '#{location.name}'"
    end
  end

  def cities_different?(current, geocoded)
    return true if current.blank? && geocoded.present?

    # Normalize for comparison
    normalize = ->(str) { str.to_s.downcase.gsub(/[^a-z0-9čćžšđ]/, "") }

    normalize.call(current) != normalize.call(geocoded)
  end

  # Returns { city: String|nil, source: :override|:geoapify|:nominatim|nil }
  def get_city_from_coordinates(lat, lng)
    return { city: nil, source: nil } if lat.blank? || lng.blank?

    lat_f = lat.to_f
    lng_f = lng.to_f

    # Check for known coordinate overrides first (for areas with incorrect data)
    override_city = check_coordinate_overrides(lat_f, lng_f)
    if override_city
      Rails.logger.info "[LocationCityFixJob] Using coordinate override for #{lat}, #{lng}: #{override_city}"
      return { city: override_city, source: :override }
    end

    # Try Geoapify first (more reliable for Balkan regions)
    city_name = get_city_from_geoapify(lat_f, lng_f)
    if city_name.present?
      Rails.logger.info "[LocationCityFixJob] Final city from Geoapify for #{lat}, #{lng}: #{city_name}"
      return { city: city_name, source: :geoapify }
    end

    # Fallback to Nominatim if Geoapify fails
    city_name = get_city_from_nominatim(lat_f, lng_f)
    if city_name.present?
      Rails.logger.info "[LocationCityFixJob] Final city from Nominatim for #{lat}, #{lng}: #{city_name}"
      return { city: city_name, source: :nominatim }
    end

    Rails.logger.info "[LocationCityFixJob] Could not extract city name for #{lat}, #{lng}"
    { city: nil, source: nil }
  end

  # Use Geoapify reverse geocoding API (primary method)
  def get_city_from_geoapify(lat, lng)
    geoapify = GeoapifyService.new
    city_name = geoapify.get_city_from_coordinates(lat, lng)

    if city_name.present?
      Rails.logger.info "[LocationCityFixJob] Geoapify returned city: #{city_name} for #{lat}, #{lng}"
    else
      Rails.logger.info "[LocationCityFixJob] Geoapify returned no city for #{lat}, #{lng}"
    end

    city_name
  rescue GeoapifyService::ConfigurationError => e
    Rails.logger.warn "[LocationCityFixJob] Geoapify not configured: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.warn "[LocationCityFixJob] Geoapify geocoding failed for #{lat}, #{lng}: #{e.message}"
    nil
  end

  # Fallback to Nominatim via Geocoder gem
  def get_city_from_nominatim(lat, lng)
    results = Geocoder.search([lat, lng])

    if results.blank?
      Rails.logger.info "[LocationCityFixJob] Nominatim returned empty results for #{lat}, #{lng}"
      return nil
    end

    result = results.first
    return nil unless result

    # Log full data for debugging
    Rails.logger.info "[LocationCityFixJob] Nominatim data for #{lat}, #{lng}:"
    Rails.logger.info "[LocationCityFixJob]   display_name: #{result.data['display_name']}"
    Rails.logger.info "[LocationCityFixJob]   address: #{result.data['address'].inspect}"

    city_name = extract_city_from_result(result)

    if city_name.blank?
      # Fallback: Try to extract from display_name (first locality-like component)
      city_name = extract_city_from_display_name(result.data["display_name"])
      if city_name.present?
        Rails.logger.info "[LocationCityFixJob] Extracted city from display_name: #{city_name}"
      end
    end

    # Clean up the city name
    clean_city_name(city_name) if city_name.present?
  rescue StandardError => e
    Rails.logger.error "[LocationCityFixJob] Nominatim geocoding failed for #{lat}, #{lng}: #{e.message}"
    Rails.logger.error "[LocationCityFixJob] Nominatim error backtrace: #{e.backtrace.first(5).join("\n")}"
    nil
  end

  # Extract city using Geocoder accessor methods and raw address data
  def extract_city_from_result(result)
    city_name = nil

    # Priority chain using Geocoder accessors (Nominatim result class has all these)
    # Note: municipality/county often return administrative regions, not cities
    # so we prioritize more specific fields
    %i[city town village suburb neighbourhood].each do |method|
      if result.respond_to?(method)
        value = result.send(method)
        if value.present?
          city_name = value
          Rails.logger.info "[LocationCityFixJob] Found city via accessor :#{method} = #{value}"
          return city_name
        end
      end
    end

    # Fall back to raw address data for additional fields
    address_data = result.data&.dig("address") || {}

    # Check hamlet/locality before falling back to municipality
    %w[hamlet locality].each do |field|
      if address_data[field].present?
        city_name = address_data[field]
        Rails.logger.info "[LocationCityFixJob] Found city via address['#{field}'] = #{city_name}"
        return city_name
      end
    end

    # Municipality/county are less reliable - they're administrative regions
    # Only use them if nothing else is available
    %w[municipality county state_district].each do |field|
      if address_data[field].present?
        city_name = address_data[field]
        Rails.logger.info "[LocationCityFixJob] Fallback to address['#{field}'] = #{city_name} (less reliable)"
        return city_name
      end
    end

    nil
  end

  # Parse display_name to extract the most likely city/town name
  # Display format is usually: "Place, Street, Town, Municipality, State, Country"
  def extract_city_from_display_name(display_name)
    return nil if display_name.blank?

    parts = display_name.split(",").map(&:strip)
    return nil if parts.length < 2

    # Skip the first part (usually the specific place/building)
    # Look for a part that looks like a city name (not a country, state, or code)
    parts[1..4].each do |part|
      next if part.blank?
      next if part.match?(/\d{5}/)  # Skip postal codes
      next if part.match?(/^(Bosnia|Herzegovina|Bosna|Srbija|Serbia|Croatia|Hrvatska)/i)
      next if part.match?(/^(Republika Srpska|Federacija|Federation)/i)

      # Found a potential city name
      return part
    end

    nil
  end

  # Clean up city name by removing administrative prefixes
  def clean_city_name(city_name)
    city_name.to_s
             .gsub(/^Grad\s+/i, "")           # "Grad Zvornik" -> "Zvornik"
             .gsub(/^Općina\s+/i, "")         # Croatian: "Općina X" -> "X"
             .gsub(/^Opština\s+/i, "")        # Serbian: "Opština X" -> "X"
             .gsub(/^Miasto\s+/i, "")         # Polish: "Miasto X" -> "X"
             .gsub(/^City of\s+/i, "")        # English
             .gsub(/^Municipality of\s+/i, "")
             .strip
  end

  # Known coordinate overrides for areas where Nominatim has incorrect data
  # These are manually verified corrections
  COORDINATE_OVERRIDES = [
    # Zvornik area coordinates incorrectly mapped to Srebrenica
    { lat_range: (44.38..44.42), lng_range: (19.08..19.14), city: "Zvornik" }
  ].freeze

  def check_coordinate_overrides(lat, lng)
    COORDINATE_OVERRIDES.each do |override|
      if override[:lat_range].cover?(lat) && override[:lng_range].cover?(lng)
        return override[:city]
      end
    end
    nil
  end

  def regenerate_location_content(location, correct_city)
    enricher = Ai::LocationEnricher.new

    # Regenerate with the correct city context
    enricher.enrich(location, place_data: { city: correct_city })
  rescue StandardError => e
    Rails.logger.warn "[LocationCityFixJob] Content regeneration failed for #{location.name}: #{e.message}"
  end

  def build_completion_summary(results)
    parts = ["Finished:"]
    parts << "#{results[:cities_corrected]} cities corrected" if results[:cities_corrected] > 0
    parts << "#{results[:content_regenerated]} descriptions regenerated (city change)" if results[:content_regenerated] > 0
    parts << "#{results[:descriptions_analyzed]} analyzed" if results[:descriptions_analyzed] > 0
    parts << "#{results[:descriptions_regenerated]} descriptions regenerated (quality)" if results[:descriptions_regenerated] > 0

    if parts.length == 1
      "Finished: No changes needed"
    else
      parts.join(", ")
    end
  end

  def save_status(status, message, results: nil)
    Setting.set("location_fix.status", status)
    Setting.set("location_fix.message", message)
    Setting.set("location_fix.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[LocationCityFixJob] Could not save status: #{e.message}"
  end

  def clear_geocoder_cache!
    # Clear all geocoder cache entries by deleting keys matching the geocoder pattern
    # This ensures fresh data is fetched from Nominatim
    if Rails.cache.respond_to?(:delete_matched)
      Rails.cache.delete_matched("geocoder:*")
    else
      # For caches that don't support delete_matched, try to clear the entire cache
      # or log a warning
      Rails.logger.warn "[LocationCityFixJob] Cache does not support delete_matched, using Rails.cache.clear"
      Rails.cache.clear
    end
  rescue StandardError => e
    Rails.logger.warn "[LocationCityFixJob] Could not clear geocoder cache: #{e.message}"
  end
end
