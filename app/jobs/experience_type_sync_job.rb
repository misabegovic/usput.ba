# frozen_string_literal: true

# Background job for syncing experience types from location's suitable_experiences JSONB field
# This creates missing ExperienceType records and populates the join table
#
# Usage:
#   ExperienceTypeSyncJob.perform_later
#   ExperienceTypeSyncJob.perform_later(dry_run: true) # Preview changes without saving
class ExperienceTypeSyncJob < ApplicationJob
  queue_as :default

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(dry_run: false)
    Rails.logger.info "[ExperienceTypeSyncJob] Starting experience type sync (dry_run: #{dry_run})"

    save_status("in_progress", "Starting experience type sync...")

    results = {
      started_at: Time.current,
      total_locations: 0,
      experience_types_created: 0,
      associations_created: 0,
      locations_updated: 0,
      new_types: [],
      errors: [],
      dry_run: dry_run
    }

    begin
      # First pass: collect all unique experience type keys from locations
      all_keys = collect_all_experience_keys(results)

      save_status("in_progress", "Found #{all_keys.size} unique experience types...")

      # Create missing experience types
      create_missing_experience_types(all_keys, results, dry_run: dry_run)

      save_status("in_progress", "Syncing location associations...")

      # Second pass: sync associations for each location
      sync_location_associations(results, dry_run: dry_run)

      results[:finished_at] = Time.current
      results[:status] = "completed"

      message = "Finished: #{results[:experience_types_created]} types created, " \
                "#{results[:associations_created]} associations, " \
                "#{results[:locations_updated]} locations updated"
      message += " (DRY RUN)" if dry_run

      save_status("completed", message, results: results)

      Rails.logger.info "[ExperienceTypeSyncJob] Completed: #{results}"
      results

    rescue StandardError => e
      results[:status] = "failed"
      results[:error] = e.message
      save_status("failed", e.message, results: results)
      Rails.logger.error "[ExperienceTypeSyncJob] Failed: #{e.message}"
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("experience_type_sync.status", default: "idle"),
      message: Setting.get("experience_type_sync.message", default: nil),
      results: JSON.parse(Setting.get("experience_type_sync.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("experience_type_sync.status", "idle")
    Setting.set("experience_type_sync.message", nil)
    Setting.set("experience_type_sync.results", "{}")
  end

  # Force reset a stuck job back to idle
  def self.force_reset!
    Setting.set("experience_type_sync.status", "idle")
    Setting.set("experience_type_sync.message", "Force reset by admin")
  end

  private

  def collect_all_experience_keys(results)
    all_keys = Set.new

    Location.where.not(suitable_experiences: nil)
            .where.not(suitable_experiences: [])
            .find_each(batch_size: 100) do |location|
      results[:total_locations] += 1

      experiences = location.read_attribute(:suitable_experiences) || []
      experiences.each do |key|
        normalized_key = key.to_s.downcase.strip
        all_keys.add(normalized_key) if normalized_key.present?
      end

      # Update status periodically
      if results[:total_locations] % 100 == 0
        save_status("in_progress", "Scanned #{results[:total_locations]} locations...")
      end
    end

    all_keys.to_a
  end

  def create_missing_experience_types(keys, results, dry_run:)
    existing_keys = ExperienceType.pluck(:key).map(&:downcase)

    keys.each do |key|
      next if existing_keys.include?(key.downcase)

      results[:new_types] << key

      unless dry_run
        ExperienceType.create!(
          key: key,
          name: key.titleize,
          active: true,
          position: ExperienceType.maximum(:position).to_i + 1
        )
        results[:experience_types_created] += 1
        Rails.logger.info "[ExperienceTypeSyncJob] Created experience type: #{key}"
      end
    end
  end

  def sync_location_associations(results, dry_run:)
    processed = 0

    Location.where.not(suitable_experiences: nil)
            .where.not(suitable_experiences: [])
            .find_each(batch_size: 50) do |location|
      processed += 1

      begin
        experiences = location.read_attribute(:suitable_experiences) || []
        location_updated = false

        experiences.each do |key|
          normalized_key = key.to_s.downcase.strip
          next if normalized_key.blank?

          exp_type = ExperienceType.find_by("LOWER(key) = ?", normalized_key)
          next unless exp_type

          # Check if association already exists
          unless location.location_experience_types.exists?(experience_type: exp_type)
            unless dry_run
              location.location_experience_types.create!(experience_type: exp_type)
            end
            results[:associations_created] += 1
            location_updated = true
          end
        end

        results[:locations_updated] += 1 if location_updated

      rescue StandardError => e
        results[:errors] << { location_id: location.id, name: location.name, error: e.message }
        Rails.logger.warn "[ExperienceTypeSyncJob] Error processing #{location.name}: #{e.message}"
      end

      # Update status periodically
      if processed % 50 == 0
        save_status("in_progress", "Processed #{processed} locations... (#{results[:associations_created]} associations created)")
      end
    end
  end

  def save_status(status, message, results: nil)
    Setting.set("experience_type_sync.status", status)
    Setting.set("experience_type_sync.message", message)
    Setting.set("experience_type_sync.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[ExperienceTypeSyncJob] Could not save status: #{e.message}"
  end
end
