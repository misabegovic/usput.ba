# frozen_string_literal: true

# Background job to fetch photos from Flickr for locations that don't have images.
# Uses location coordinates, name, and description to search for relevant Creative Commons photos.
#
# Usage:
#   FetchFlickrPhotosJob.perform_later
#   FetchFlickrPhotosJob.perform_later(max_locations: 50, max_photos_per_location: 5)
#   FetchFlickrPhotosJob.perform_later(city: "Sarajevo")
#   FetchFlickrPhotosJob.perform_later(location_ids: [1, 2, 3])
#
class FetchFlickrPhotosJob < ApplicationJob
  queue_as :default

  retry_on FlickrService::ApiError, wait: :polynomially_longer, attempts: 3
  discard_on FlickrService::ConfigurationError

  STATUS_KEY = "flickr_photos_job_status"
  RESULTS_KEY = "flickr_photos_job_results"

  # @param max_locations [Integer, nil] Maximum locations to process (nil = all)
  # @param max_photos_per_location [Integer] Maximum photos per location (default: 5)
  # @param city [String, nil] Only process locations in this city
  # @param location_ids [Array<Integer>, nil] Only process these specific locations
  # @param dry_run [Boolean] If true, only report what would be done
  def perform(max_locations: nil, max_photos_per_location: 5, city: nil, location_ids: nil, dry_run: false)
    save_status("in_progress", "Starting Flickr photo fetch...")

    locations = find_locations_without_photos(city: city, location_ids: location_ids)
    locations = locations.limit(max_locations) if max_locations.present? && max_locations > 0

    total_count = locations.count
    save_status("in_progress", "Found #{total_count} locations without photos")

    if dry_run
      complete_dry_run(locations, total_count)
      return
    end

    results = process_locations(locations, max_photos_per_location, total_count)
    complete_job(results)
  rescue StandardError => e
    save_status("failed", "Job failed: #{e.message}")
    raise
  end

  # Get current job status for admin UI
  def self.current_status
    status = Setting.get(STATUS_KEY, default: "idle")
    results = Setting.get(RESULTS_KEY, default: {})

    {
      status: status.is_a?(Hash) ? status[:status] : status,
      message: status.is_a?(Hash) ? status[:message] : nil,
      results: results
    }
  end

  # Clear job status for new run
  def self.clear_status!
    Setting.set(STATUS_KEY, "idle")
    Setting.set(RESULTS_KEY, {})
  end

  private

  def find_locations_without_photos(city: nil, location_ids: nil)
    scope = Location.left_joins(:photos_attachments)
                    .where(active_storage_attachments: { id: nil })
                    .where.not(lat: nil, lng: nil)

    scope = scope.where(city: city) if city.present?
    scope = scope.where(id: location_ids) if location_ids.present?

    scope.order(:city, :name)
  end

  def process_locations(locations, max_photos_per_location, total_count)
    service = FlickrService.new
    results = {
      processed: 0,
      photos_attached: 0,
      skipped: 0,
      errors: [],
      locations_updated: []
    }

    locations.find_each.with_index do |location, index|
      save_status(
        "in_progress",
        "Processing #{index + 1}/#{total_count}: #{location.name} (#{location.city})"
      )

      begin
        result = process_single_location(service, location, max_photos_per_location)
        results[:processed] += 1
        results[:photos_attached] += result[:attached]
        results[:skipped] += result[:skipped]

        if result[:attached] > 0
          results[:locations_updated] << {
            id: location.id,
            name: location.name,
            city: location.city,
            photos_added: result[:attached]
          }
        end

        results[:errors].concat(result[:errors]) if result[:errors].any?

        # Rate limiting - be nice to Flickr API
        sleep(0.5)
      rescue StandardError => e
        results[:errors] << {
          location_id: location.id,
          location_name: location.name,
          error: e.message
        }
        Rails.logger.error("[FetchFlickrPhotosJob] Error processing location #{location.id}: #{e.message}")
      end

      # Update results periodically
      save_results(results) if (index + 1) % 10 == 0
    end

    results
  end

  def process_single_location(service, location, max_photos)
    # Search for photos
    photos = service.search_photos_for_location(location, max_results: max_photos * 2)

    if photos.empty?
      Rails.logger.info("[FetchFlickrPhotosJob] No photos found for location #{location.id}: #{location.name}")
      return { attached: 0, skipped: 0, errors: [] }
    end

    # Download and attach photos
    service.download_and_attach_photos(location, photos, max: max_photos)
  end

  def complete_dry_run(locations, total_count)
    preview = locations.limit(20).map do |loc|
      {
        id: loc.id,
        name: loc.name,
        city: loc.city,
        lat: loc.lat,
        lng: loc.lng
      }
    end

    results = {
      dry_run: true,
      total_locations: total_count,
      preview: preview
    }

    save_results(results)
    save_status("completed", "Dry run complete. Found #{total_count} locations without photos.")
  end

  def complete_job(results)
    save_results(results)
    save_status(
      "completed",
      "Completed! Processed #{results[:processed]} locations, attached #{results[:photos_attached]} photos."
    )
  end

  def save_status(status, message)
    Setting.set(STATUS_KEY, { status: status, message: message, updated_at: Time.current })
  end

  def save_results(results)
    Setting.set(RESULTS_KEY, results)
  end
end
