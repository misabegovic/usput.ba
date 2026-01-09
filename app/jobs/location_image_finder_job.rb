# frozen_string_literal: true

# Background job for finding and attaching images to locations using Google Custom Search API.
#
# Usage:
#   LocationImageFinderJob.perform_later                              # Process locations without photos
#   LocationImageFinderJob.perform_later(city: "Sarajevo")            # Only Sarajevo locations
#   LocationImageFinderJob.perform_later(max_locations: 10)           # Limit to 10 locations
#   LocationImageFinderJob.perform_later(images_per_location: 3)      # Get 3 images per location
#   LocationImageFinderJob.perform_later(dry_run: true)               # Preview without saving
#   LocationImageFinderJob.perform_later(creative_commons_only: true) # Only CC-licensed images
#
class LocationImageFinderJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient failures with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on GoogleImageSearchService::ConfigurationError

  # Don't retry on quota exceeded - need to wait for next day
  discard_on GoogleImageSearchService::QuotaExceededError

  # Delay between API calls to avoid rate limiting (in seconds)
  API_DELAY = 1

  # Default values
  DEFAULT_MAX_LOCATIONS = 10
  DEFAULT_IMAGES_PER_LOCATION = 3

  def perform(
    city: nil,
    max_locations: DEFAULT_MAX_LOCATIONS,
    images_per_location: DEFAULT_IMAGES_PER_LOCATION,
    dry_run: false,
    creative_commons_only: false,
    location_id: nil
  )
    Rails.logger.info "[LocationImageFinderJob] Starting (city: #{city || 'all'}, max: #{max_locations}, dry_run: #{dry_run})"

    save_status("in_progress", "Initializing Google image search...")

    results = {
      started_at: Time.current,
      dry_run: dry_run,
      city: city,
      max_locations: max_locations,
      images_per_location: images_per_location,
      creative_commons_only: creative_commons_only,
      locations_processed: 0,
      images_found: 0,
      images_attached: 0,
      errors: [],
      location_results: []
    }

    begin
      service = GoogleImageSearchService.new

      # Build query for locations without photos
      locations = build_locations_query(city: city, location_id: location_id)
      total_without_photos = locations.count

      results[:total_locations_without_photos] = total_without_photos
      save_status("in_progress", "Found #{total_without_photos} locations without photos")

      if total_without_photos.zero?
        results[:status] = "completed"
        results[:message] = "No locations need photos"
        results[:finished_at] = Time.current
        save_status("completed", "No locations need photos", results: results)
        return results
      end

      # Apply limit
      locations = locations.limit(max_locations)

      # Process each location
      locations.find_each.with_index do |location, index|
        break if index >= max_locations

        process_location(
          location,
          service,
          results,
          images_per_location: images_per_location,
          dry_run: dry_run,
          creative_commons_only: creative_commons_only,
          index: index + 1,
          total: [total_without_photos, max_locations].min
        )

        # Rate limiting delay between API calls
        sleep(API_DELAY) unless dry_run
      end

      results[:status] = "completed"
      results[:finished_at] = Time.current

      summary = "Completed: #{results[:images_found]} images found, #{results[:images_attached]} attached, #{results[:errors].count} errors"
      save_status("completed", summary, results: results)

      Rails.logger.info "[LocationImageFinderJob] #{summary}"
      results

    rescue GoogleImageSearchService::ConfigurationError => e
      results[:status] = "failed"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("failed", "Configuration error: #{e.message}", results: results)
      Rails.logger.error "[LocationImageFinderJob] Configuration error: #{e.message}"
      raise

    rescue GoogleImageSearchService::QuotaExceededError => e
      results[:status] = "quota_exceeded"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("quota_exceeded", "Quota exceeded: #{e.message}", results: results)
      Rails.logger.warn "[LocationImageFinderJob] Quota exceeded: #{e.message}"
      raise

    rescue StandardError => e
      results[:status] = "failed"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("failed", e.message, results: results)
      Rails.logger.error "[LocationImageFinderJob] Failed: #{e.message}"
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("location_image_finder.status", default: "idle"),
      message: Setting.get("location_image_finder.message", default: nil),
      results: JSON.parse(Setting.get("location_image_finder.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("location_image_finder.status", "idle")
    Setting.set("location_image_finder.message", nil)
    Setting.set("location_image_finder.results", "{}")
  end

  # Force reset a stuck or in-progress job back to idle
  def self.force_reset!
    Setting.set("location_image_finder.status", "idle")
    Setting.set("location_image_finder.message", "Force reset by admin")
  end

  private

  def build_locations_query(city: nil, location_id: nil)
    # Find locations without any attached photos
    locations_with_photos_ids = ActiveStorage::Attachment
      .where(record_type: "Location", name: "photos")
      .distinct
      .pluck(:record_id)

    locations = Location.where.not(id: locations_with_photos_ids)

    if location_id.present?
      locations = locations.where(id: location_id)
    elsif city.present?
      locations = locations.where(city: city)
    end

    # Prioritize locations by importance
    locations
      .left_joins(:location_categories)
      .select("locations.*, COUNT(location_categories.id) as category_count")
      .group("locations.id")
      .order(Arel.sql("COUNT(location_categories.id) DESC, locations.created_at DESC"))
  end

  def process_location(location, service, results, images_per_location:, dry_run:, creative_commons_only:, index:, total:)
    save_status("in_progress", "Processing #{index}/#{total}: #{location.name}")

    location_result = {
      id: location.id,
      name: location.name,
      city: location.city,
      images_found: 0,
      images_attached: 0,
      images: []
    }

    begin
      # Search for images
      images = service.search_location(
        location.name,
        city: location.city,
        num: images_per_location,
        creative_commons_only: creative_commons_only
      )

      location_result[:images_found] = images.count
      results[:images_found] += images.count

      images.each do |image|
        image_info = {
          url: image[:url],
          title: image[:title],
          thumbnail: image[:thumbnail],
          source: image[:source],
          attached: false
        }

        unless dry_run
          if attach_image_to_location(location, image)
            image_info[:attached] = true
            location_result[:images_attached] += 1
            results[:images_attached] += 1
          end
        end

        location_result[:images] << image_info
      end

      results[:locations_processed] += 1
      Rails.logger.info "[LocationImageFinderJob] #{dry_run ? '[DRY RUN] ' : ''}Found #{images.count} images for #{location.name}"

    rescue GoogleImageSearchService::QuotaExceededError
      # Re-raise quota errors to stop processing
      raise
    rescue GoogleImageSearchService::ApiError => e
      location_result[:error] = e.message
      results[:errors] << {
        location_id: location.id,
        name: location.name,
        error: e.message
      }
      Rails.logger.warn "[LocationImageFinderJob] API error for #{location.name}: #{e.message}"
    rescue StandardError => e
      location_result[:error] = e.message
      results[:errors] << {
        location_id: location.id,
        name: location.name,
        error: e.message
      }
      Rails.logger.warn "[LocationImageFinderJob] Error for #{location.name}: #{e.message}"
    end

    results[:location_results] << location_result
  end

  def attach_image_to_location(location, image)
    return false if image[:url].blank?

    # Download and attach the image
    downloaded = download_image(image[:url])
    return false unless downloaded

    filename = generate_filename(location, image)

    location.photos.attach(
      io: downloaded[:io],
      filename: filename,
      content_type: downloaded[:content_type]
    )

    Rails.logger.info "[LocationImageFinderJob] Attached image to #{location.name}: #{filename}"
    true

  rescue ActiveStorage::IntegrityError => e
    Rails.logger.warn "[LocationImageFinderJob] Integrity error attaching image: #{e.message}"
    false
  rescue StandardError => e
    Rails.logger.warn "[LocationImageFinderJob] Failed to attach image: #{e.message}"
    false
  end

  def download_image(url)
    connection = Faraday.new do |faraday|
      faraday.options.timeout = 30
      faraday.options.open_timeout = 10
      faraday.response :follow_redirects, limit: 3
      faraday.adapter Faraday.default_adapter
    end

    response = connection.get(url)

    return nil unless response.success?

    content_type = response.headers["content-type"]&.split(";")&.first

    # Validate content type
    valid_types = %w[image/jpeg image/png image/webp image/gif]
    unless valid_types.include?(content_type)
      Rails.logger.warn "[LocationImageFinderJob] Invalid content type: #{content_type}"
      return nil
    end

    # Validate file size (max 10MB)
    max_size = 10 * 1024 * 1024
    if response.body.bytesize > max_size
      Rails.logger.warn "[LocationImageFinderJob] Image too large: #{response.body.bytesize} bytes"
      return nil
    end

    {
      io: StringIO.new(response.body),
      content_type: content_type
    }

  rescue Faraday::Error => e
    Rails.logger.warn "[LocationImageFinderJob] Failed to download image: #{e.message}"
    nil
  end

  def generate_filename(location, image)
    extension = case image[:mime_type]
                when "image/png" then ".png"
                when "image/webp" then ".webp"
                when "image/gif" then ".gif"
                else ".jpg"
                end

    "#{location.name.parameterize}-#{SecureRandom.hex(4)}#{extension}"
  end

  def save_status(status, message, results: nil)
    Setting.set("location_image_finder.status", status)
    Setting.set("location_image_finder.message", message)
    Setting.set("location_image_finder.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[LocationImageFinderJob] Could not save status: #{e.message}"
  end
end
