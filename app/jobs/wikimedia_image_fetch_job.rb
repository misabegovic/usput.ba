# frozen_string_literal: true

# Background job for fetching images from Wikimedia Commons for locations without photos.
# Selects random locations that have no attached photos and searches Wikimedia Commons
# for relevant images based on location name and city.
#
# Usage:
#   WikimediaImageFetchJob.perform_later
#   WikimediaImageFetchJob.perform_later(dry_run: true) # Preview mode - don't attach images
#   WikimediaImageFetchJob.perform_later(max_locations: 5) # Process up to 5 locations
#   WikimediaImageFetchJob.perform_later(images_per_location: 3) # Fetch 3 images per location
#   WikimediaImageFetchJob.perform_later(use_coordinates: true) # Also search by GPS coordinates
#   WikimediaImageFetchJob.perform_later(replace_photos: true) # Replace existing photos
#
class WikimediaImageFetchJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Discard on permanent failures
  discard_on WikimediaService::ApiError

  # Default settings
  DEFAULT_MAX_LOCATIONS = 10
  DEFAULT_IMAGES_PER_LOCATION = 5
  MAX_IMAGES_PER_LOCATION = 10

  def perform(dry_run: false, max_locations: nil, images_per_location: nil, use_coordinates: true, replace_photos: false)
    max_locations ||= DEFAULT_MAX_LOCATIONS
    images_per_location ||= DEFAULT_IMAGES_PER_LOCATION
    images_per_location = [images_per_location, MAX_IMAGES_PER_LOCATION].min

    Rails.logger.info "[WikimediaImageFetchJob] Starting (dry_run: #{dry_run}, max_locations: #{max_locations}, images_per_location: #{images_per_location}, replace_photos: #{replace_photos})"

    save_status("in_progress", "Starting Wikimedia image fetch...")

    results = {
      started_at: Time.current,
      dry_run: dry_run,
      replace_photos: replace_photos,
      total_locations_checked: 0,
      locations_processed: 0,
      images_found: 0,
      images_attached: 0,
      photos_removed: 0,
      errors: [],
      location_results: []
    }

    begin
      service = WikimediaService.new

      # Find locations to process
      locations_to_process = find_locations_to_process(max_locations, replace_photos: replace_photos)

      if locations_to_process.empty?
        results[:status] = "completed"
        results[:finished_at] = Time.current
        message = replace_photos ? "No locations with photos found" : "No locations without photos found"
        save_status("completed", message, results: results)
        return results
      end

      results[:total_locations_checked] = locations_to_process.count

      locations_to_process.each_with_index do |location, index|
        begin
          save_status("in_progress", "Processing #{index + 1}/#{locations_to_process.count}: #{location.name}")

          location_result = process_location(location, service,
            dry_run: dry_run,
            images_per_location: images_per_location,
            use_coordinates: use_coordinates,
            replace_photos: replace_photos
          )

          results[:location_results] << location_result
          results[:locations_processed] += 1
          results[:images_found] += location_result[:images_found]
          results[:images_attached] += location_result[:images_attached]
          results[:photos_removed] += location_result[:photos_removed] || 0

        rescue StandardError => e
          error_info = {
            location_id: location.id,
            name: location.name,
            error: e.message
          }
          results[:errors] << error_info
          Rails.logger.warn "[WikimediaImageFetchJob] Error processing #{location.name}: #{e.message}"
        end
      end

      results[:status] = "completed"
      results[:finished_at] = Time.current

      summary = build_completion_summary(results)
      save_status("completed", summary, results: results)

      Rails.logger.info "[WikimediaImageFetchJob] Completed: #{summary}"
      results

    rescue StandardError => e
      results[:status] = "failed"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("failed", e.message, results: results)
      Rails.logger.error "[WikimediaImageFetchJob] Failed: #{e.message}"
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("wikimedia_fetch.status", default: "idle"),
      message: Setting.get("wikimedia_fetch.message", default: nil),
      results: JSON.parse(Setting.get("wikimedia_fetch.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("wikimedia_fetch.status", "idle")
    Setting.set("wikimedia_fetch.message", nil)
    Setting.set("wikimedia_fetch.results", "{}")
  end

  # Force reset a stuck job
  def self.force_reset!
    Setting.set("wikimedia_fetch.status", "idle")
    Setting.set("wikimedia_fetch.message", "Force reset by admin")
  end

  private

  # Find locations to process based on replace_photos flag
  # Selects random locations to distribute image fetching
  def find_locations_to_process(limit, replace_photos: false)
    # Get location IDs that have photos
    locations_with_photos_ids = ActiveStorage::Attachment
      .where(record_type: "Location", name: "photos")
      .distinct
      .pluck(:record_id)

    # Find locations with or without photos based on replace_photos flag
    locations = if replace_photos
      # When replacing, find locations WITH photos
      Location.where(id: locations_with_photos_ids)
    else
      # Default: find locations WITHOUT photos
      Location.where.not(id: locations_with_photos_ids)
    end

    locations
      .with_coordinates
      .order(Arel.sql("RANDOM()"))
      .limit(limit)
  end

  # Process a single location - search for images and optionally attach them
  def process_location(location, service, dry_run:, images_per_location:, use_coordinates:, replace_photos: false)
    result = {
      location_id: location.id,
      name: location.name,
      city: location.city,
      images_found: 0,
      images_attached: 0,
      photos_removed: 0,
      images: []
    }

    # Build search query
    search_query = build_search_query(location)
    Rails.logger.info "[WikimediaImageFetchJob] Searching for: #{search_query}"

    # Search by text query
    images = service.search_images(search_query, limit: images_per_location)

    # Also search by coordinates if enabled and location has them
    if use_coordinates && location.geocoded? && images.length < images_per_location
      Rails.logger.info "[WikimediaImageFetchJob] Also searching by coordinates: #{location.lat}, #{location.lng}"
      coord_images = service.search_by_coordinates(
        location.lat,
        location.lng,
        radius: 500,
        limit: images_per_location - images.length
      )

      # Merge results, avoiding duplicates by URL
      existing_urls = images.map { |i| i[:url] }
      coord_images.each do |img|
        images << img unless existing_urls.include?(img[:url])
      end
    end

    result[:images_found] = images.length

    if images.empty?
      Rails.logger.info "[WikimediaImageFetchJob] No images found for #{location.name}"
      return result
    end

    # If replacing photos and we found new images, remove existing photos first
    if replace_photos && images.any? && !dry_run
      existing_photos_count = location.photos.count
      if existing_photos_count > 0
        location.photos.purge
        result[:photos_removed] = existing_photos_count
        Rails.logger.info "[WikimediaImageFetchJob] Removed #{existing_photos_count} existing photos from #{location.name}"
      end
    end

    # Process each found image
    images.each do |image|
      image_result = {
        title: image[:title],
        url: image[:url],
        thumb_url: image[:thumb_url],
        description: image[:description],
        license: image[:license],
        author: image[:author],
        width: image[:width],
        height: image[:height],
        page_url: image[:page_url],
        attached: false
      }

      unless dry_run
        # Download and attach image
        if attach_image_to_location(location, image, service)
          image_result[:attached] = true
          result[:images_attached] += 1
        end
      end

      result[:images] << image_result
    end

    result
  end

  # Build search query from location data
  def build_search_query(location)
    parts = []

    # Primary: location name
    parts << location.name if location.name.present?

    # Add city for context
    parts << location.city if location.city.present?

    # Join with space
    parts.join(" ")
  end

  # Download and attach image to location
  def attach_image_to_location(location, image, service)
    return false unless image[:url].present?

    Rails.logger.info "[WikimediaImageFetchJob] Downloading: #{image[:url]}"

    io = service.download_image(image[:url])
    return false unless io

    # Determine filename
    filename = File.basename(URI.parse(image[:url]).path)
    filename = "wikimedia_#{SecureRandom.hex(4)}.jpg" if filename.blank?

    # Determine content type
    content_type = image[:mime] || "image/jpeg"

    # Attach to location
    location.photos.attach(
      io: io,
      filename: filename,
      content_type: content_type
    )

    Rails.logger.info "[WikimediaImageFetchJob] Attached #{filename} to #{location.name}"
    true

  rescue StandardError => e
    Rails.logger.warn "[WikimediaImageFetchJob] Failed to attach image: #{e.message}"
    false
  ensure
    io&.close if io.respond_to?(:close)
  end

  def build_completion_summary(results)
    parts = []

    if results[:dry_run]
      parts << "Preview completed:"
    else
      parts << "Completed:"
    end

    parts << "#{results[:locations_processed]} locations processed"
    parts << "#{results[:images_found]} images found"

    unless results[:dry_run]
      parts << "#{results[:images_attached]} images attached"
      if results[:replace_photos] && results[:photos_removed] > 0
        parts << "#{results[:photos_removed]} photos removed"
      end
    end

    if results[:errors].any?
      parts << "#{results[:errors].count} errors"
    end

    parts.join(", ")
  end

  def save_status(status, message, results: nil)
    Setting.set("wikimedia_fetch.status", status)
    Setting.set("wikimedia_fetch.message", message)
    Setting.set("wikimedia_fetch.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[WikimediaImageFetchJob] Could not save status: #{e.message}"
  end
end
