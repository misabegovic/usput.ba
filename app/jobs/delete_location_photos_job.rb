# frozen_string_literal: true

# Background job for deleting all photos from a location by ID.
#
# Usage:
#   DeleteLocationPhotosJob.perform_later(location_id: 123)           # Delete photos for single location
#   DeleteLocationPhotosJob.perform_later(location_ids: [1, 2, 3])    # Delete photos for multiple locations
#   DeleteLocationPhotosJob.perform_later(city: "Sarajevo")           # Delete photos for all locations in city
#   DeleteLocationPhotosJob.perform_later(location_id: 123, dry_run: true)  # Preview without deleting
#
class DeleteLocationPhotosJob < ApplicationJob
  queue_as :default

  def perform(location_id: nil, location_ids: nil, city: nil, dry_run: false)
    Rails.logger.info "[DeleteLocationPhotosJob] Starting (location_id: #{location_id}, location_ids: #{location_ids&.size}, city: #{city}, dry_run: #{dry_run})"

    save_status("in_progress", "Starting photo deletion...")

    results = {
      started_at: Time.current,
      dry_run: dry_run,
      location_id: location_id,
      location_ids: location_ids,
      city: city,
      locations_processed: 0,
      photos_deleted: 0,
      errors: [],
      location_results: []
    }

    begin
      locations = find_locations(location_id: location_id, location_ids: location_ids, city: city)

      if locations.empty?
        results[:status] = "completed"
        results[:message] = "No locations found to process"
        results[:finished_at] = Time.current
        save_status("completed", results[:message], results: results)
        return results
      end

      results[:total_locations] = locations.size
      save_status("in_progress", "Found #{locations.size} locations to process")

      locations.find_each.with_index do |location, index|
        save_status("in_progress", "Processing #{index + 1}/#{results[:total_locations]}: #{location.name}")
        process_location(location, results, dry_run: dry_run)
      end

      results[:status] = "completed"
      results[:message] = build_completion_summary(results)
      results[:finished_at] = Time.current

      save_status("completed", results[:message], results: results)
      results
    rescue StandardError => e
      results[:status] = "failed"
      results[:message] = "Error: #{e.message}"
      results[:finished_at] = Time.current
      save_status("failed", results[:message], results: results)
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("delete_location_photos.status", default: "idle"),
      message: Setting.get("delete_location_photos.message", default: nil),
      results: JSON.parse(Setting.get("delete_location_photos.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("delete_location_photos.status", "idle")
    Setting.set("delete_location_photos.message", nil)
    Setting.set("delete_location_photos.results", "{}")
  end

  # Force reset a stuck job
  def self.force_reset!
    Setting.set("delete_location_photos.status", "idle")
    Setting.set("delete_location_photos.message", "Force reset by admin")
  end

  private

  def find_locations(location_id:, location_ids:, city:)
    if location_id.present?
      Location.where(id: location_id)
    elsif location_ids.present?
      Location.where(id: location_ids)
    elsif city.present?
      Location.where(city: city)
    else
      Location.none
    end
  end

  def process_location(location, results, dry_run:)
    photo_count = location.photos.count

    if photo_count.zero?
      Rails.logger.info "[DeleteLocationPhotosJob] Location #{location.id} (#{location.name}) has no photos, skipping"
      return
    end

    Rails.logger.info "[DeleteLocationPhotosJob] #{dry_run ? '[DRY RUN] Would delete' : 'Deleting'} #{photo_count} photos from location #{location.id} (#{location.name})"

    location_result = {
      id: location.id,
      name: location.name,
      city: location.city,
      photos_count: photo_count
    }

    unless dry_run
      begin
        location.photos.purge
        location_result[:status] = "deleted"
      rescue StandardError => e
        Rails.logger.error "[DeleteLocationPhotosJob] Error deleting photos for location #{location.id}: #{e.message}"
        location_result[:status] = "error"
        location_result[:error] = e.message
        results[:errors] << { location_id: location.id, error: e.message }
      end
    else
      location_result[:status] = "would_delete"
    end

    results[:locations_processed] += 1
    results[:photos_deleted] += photo_count unless dry_run || location_result[:status] == "error"
    results[:location_results] << location_result
  end

  def build_completion_summary(results)
    parts = []

    if results[:dry_run]
      parts << "Preview completed:"
    else
      parts << "Completed:"
    end

    parts << "#{results[:locations_processed]} locations processed"
    parts << "#{results[:photos_deleted]} photos deleted"

    if results[:errors].any?
      parts << "#{results[:errors].count} errors"
    end

    parts.join(", ")
  end

  def save_status(status, message, results: nil)
    Setting.set("delete_location_photos.status", status)
    Setting.set("delete_location_photos.message", message)
    Setting.set("delete_location_photos.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[DeleteLocationPhotosJob] Could not save status: #{e.message}"
  end
end
