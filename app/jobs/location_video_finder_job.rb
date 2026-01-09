# frozen_string_literal: true

# Background job for finding and adding YouTube videos to locations that don't have one.
# Uses Perplexity AI's web search to find the best video for each location.
#
# Usage:
#   LocationVideoFinderJob.perform_later                           # Process all locations without videos
#   LocationVideoFinderJob.perform_later(city: "Sarajevo")         # Only Sarajevo locations
#   LocationVideoFinderJob.perform_later(max_locations: 10)        # Limit to 10 locations
#   LocationVideoFinderJob.perform_later(dry_run: true)            # Preview without saving
#   LocationVideoFinderJob.perform_later(location_id: 123)         # Process specific location
#
class LocationVideoFinderJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient failures with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on Ai::LocationVideoFinder::ConfigurationError

  # Default batch size for processing
  DEFAULT_BATCH_SIZE = 50

  # Delay between API calls to avoid rate limiting (in seconds)
  API_DELAY = 2

  def perform(city: nil, max_locations: nil, dry_run: false, location_id: nil)
    Rails.logger.info "[LocationVideoFinderJob] Starting (city: #{city || 'all'}, max: #{max_locations || 'unlimited'}, dry_run: #{dry_run})"

    save_status("in_progress", "Initializing video search...")

    results = {
      started_at: Time.current,
      dry_run: dry_run,
      city: city,
      max_locations: max_locations,
      locations_processed: 0,
      videos_found: 0,
      videos_saved: 0,
      errors: [],
      details: []
    }

    begin
      finder = Ai::LocationVideoFinder.new

      # Build query for locations without videos
      locations = build_locations_query(city: city, location_id: location_id)
      total_count = locations.count

      results[:total_locations] = total_count
      save_status("in_progress", "Found #{total_count} locations without videos")

      if total_count.zero?
        results[:status] = "completed"
        results[:message] = "No locations need video updates"
        results[:finished_at] = Time.current
        save_status("completed", "No locations need video updates", results: results)
        return results
      end

      # Apply limit if specified
      locations = locations.limit(max_locations) if max_locations.present?

      # Process each location
      locations.find_each.with_index do |location, index|
        break if max_locations.present? && index >= max_locations

        process_location(location, finder, results, dry_run: dry_run, index: index + 1, total: [total_count, max_locations].compact.min)

        # Rate limiting delay between API calls
        sleep(API_DELAY) unless dry_run
      end

      results[:status] = "completed"
      results[:finished_at] = Time.current

      summary = "Completed: #{results[:videos_found]} videos found, #{results[:videos_saved]} saved, #{results[:errors].count} errors"
      save_status("completed", summary, results: results)

      Rails.logger.info "[LocationVideoFinderJob] #{summary}"
      results

    rescue Ai::LocationVideoFinder::ConfigurationError => e
      results[:status] = "failed"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("failed", "Configuration error: #{e.message}", results: results)
      Rails.logger.error "[LocationVideoFinderJob] Configuration error: #{e.message}"
      raise

    rescue StandardError => e
      results[:status] = "failed"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("failed", e.message, results: results)
      Rails.logger.error "[LocationVideoFinderJob] Failed: #{e.message}"
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("location_video_finder.status", default: "idle"),
      message: Setting.get("location_video_finder.message", default: nil),
      results: JSON.parse(Setting.get("location_video_finder.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("location_video_finder.status", "idle")
    Setting.set("location_video_finder.message", nil)
    Setting.set("location_video_finder.results", "{}")
  end

  # Force reset a stuck or in-progress job back to idle
  def self.force_reset!
    Setting.set("location_video_finder.status", "idle")
    Setting.set("location_video_finder.message", "Force reset by admin")
  end

  private

  def build_locations_query(city: nil, location_id: nil)
    locations = Location.where(video_url: [nil, ""])

    if location_id.present?
      locations = locations.where(id: location_id)
    elsif city.present?
      locations = locations.where(city: city)
    end

    # Prioritize locations that have more content (description, categories, etc.)
    # and are more likely to have good YouTube coverage
    locations
      .left_joins(:location_categories)
      .select("locations.*, COUNT(location_categories.id) as category_count")
      .group("locations.id")
      .order(Arel.sql("COUNT(location_categories.id) DESC, locations.created_at DESC"))
  end

  def process_location(location, finder, results, dry_run:, index:, total:)
    save_status("in_progress", "Processing #{index}/#{total}: #{location.name}")

    begin
      video_result = finder.find_video_for(location)
      results[:locations_processed] += 1

      if video_result
        results[:videos_found] += 1

        detail = {
          location_id: location.id,
          location_name: location.name,
          city: location.city,
          video_url: video_result[:video_url],
          video_title: video_result[:title],
          channel: video_result[:channel],
          reason: video_result[:reason],
          saved: false
        }

        unless dry_run
          if location.update(video_url: video_result[:video_url])
            results[:videos_saved] += 1
            detail[:saved] = true
            Rails.logger.info "[LocationVideoFinderJob] Saved video for #{location.name}: #{video_result[:video_url]}"
          else
            results[:errors] << {
              location_id: location.id,
              location_name: location.name,
              error: location.errors.full_messages.join(", ")
            }
            Rails.logger.warn "[LocationVideoFinderJob] Failed to save video for #{location.name}: #{location.errors.full_messages.join(', ')}"
          end
        else
          Rails.logger.info "[LocationVideoFinderJob] [DRY RUN] Would save video for #{location.name}: #{video_result[:video_url]}"
        end

        results[:details] << detail
      else
        Rails.logger.info "[LocationVideoFinderJob] No video found for #{location.name}"
        results[:details] << {
          location_id: location.id,
          location_name: location.name,
          city: location.city,
          video_url: nil,
          reason: "No suitable video found"
        }
      end

    rescue Ai::LocationVideoFinder::SearchError => e
      results[:errors] << {
        location_id: location.id,
        location_name: location.name,
        error: e.message
      }
      Rails.logger.warn "[LocationVideoFinderJob] Search error for #{location.name}: #{e.message}"
    end
  end

  def save_status(status, message, results: nil)
    Setting.set("location_video_finder.status", status)
    Setting.set("location_video_finder.message", message)
    Setting.set("location_video_finder.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[LocationVideoFinderJob] Could not save status: #{e.message}"
  end
end
