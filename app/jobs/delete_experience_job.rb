# frozen_string_literal: true

# Background job for deleting experiences by UUID or title.
#
# Usage:
#   DeleteExperienceJob.perform_later(experience_id: "uuid")           # Delete single experience by UUID
#   DeleteExperienceJob.perform_later(experience_ids: ["uuid1", "uuid2"])  # Delete multiple experiences by UUID
#   DeleteExperienceJob.perform_later(title: "Experience Name")        # Delete experience by exact title match
#   DeleteExperienceJob.perform_later(experience_id: "uuid", dry_run: true)  # Preview without deleting
#
class DeleteExperienceJob < ApplicationJob
  queue_as :default

  def perform(experience_id: nil, experience_ids: nil, title: nil, dry_run: false)
    Rails.logger.info "[DeleteExperienceJob] Starting (experience_id: #{experience_id}, experience_ids: #{experience_ids&.size}, title: #{title}, dry_run: #{dry_run})"

    save_status("in_progress", "Starting experience deletion...")

    results = {
      started_at: Time.current,
      dry_run: dry_run,
      experience_id: experience_id,
      experience_ids: experience_ids,
      title: title,
      experiences_processed: 0,
      experiences_deleted: 0,
      errors: [],
      experience_results: []
    }

    begin
      experiences = find_experiences(experience_id: experience_id, experience_ids: experience_ids, title: title)

      if experiences.empty?
        results[:status] = "completed"
        results[:message] = "No experiences found to process"
        results[:finished_at] = Time.current
        save_status("completed", results[:message], results: results)
        return results
      end

      results[:total_experiences] = experiences.size
      save_status("in_progress", "Found #{experiences.size} experiences to process")

      experiences.find_each.with_index do |experience, index|
        save_status("in_progress", "Processing #{index + 1}/#{results[:total_experiences]}: #{experience.title}")
        process_experience(experience, results, dry_run: dry_run)
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
      status: Setting.get("delete_experience.status", default: "idle"),
      message: Setting.get("delete_experience.message", default: nil),
      results: JSON.parse(Setting.get("delete_experience.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("delete_experience.status", "idle")
    Setting.set("delete_experience.message", nil)
    Setting.set("delete_experience.results", "{}")
  end

  # Force reset a stuck job
  def self.force_reset!
    Setting.set("delete_experience.status", "idle")
    Setting.set("delete_experience.message", "Force reset by admin")
  end

  private

  def find_experiences(experience_id:, experience_ids:, title:)
    if experience_id.present?
      Experience.where(id: experience_id)
    elsif experience_ids.present?
      Experience.where(id: experience_ids)
    elsif title.present?
      Experience.where(title: title)
    else
      Experience.none
    end
  end

  def process_experience(experience, results, dry_run:)
    Rails.logger.info "[DeleteExperienceJob] #{dry_run ? '[DRY RUN] Would delete' : 'Deleting'} experience #{experience.id} (#{experience.title})"

    experience_result = {
      id: experience.id,
      title: experience.title,
      city: experience.city,
      locations_count: experience.locations_count,
      has_cover_photo: experience.cover_photo.attached?
    }

    unless dry_run
      begin
        # Delete the experience - dependent: :destroy will handle associations
        experience.destroy!
        experience_result[:status] = "deleted"
      rescue StandardError => e
        Rails.logger.error "[DeleteExperienceJob] Error deleting experience #{experience.id}: #{e.message}"
        experience_result[:status] = "error"
        experience_result[:error] = e.message
        results[:errors] << { experience_id: experience.id, error: e.message }
      end
    else
      experience_result[:status] = "would_delete"
    end

    results[:experiences_processed] += 1
    results[:experiences_deleted] += 1 unless dry_run || experience_result[:status] == "error"
    results[:experience_results] << experience_result
  end

  def build_completion_summary(results)
    parts = []

    if results[:dry_run]
      parts << "Preview completed:"
    else
      parts << "Completed:"
    end

    parts << "#{results[:experiences_processed]} experiences processed"
    parts << "#{results[:experiences_deleted]} experiences deleted"

    if results[:errors].any?
      parts << "#{results[:errors].count} errors"
    end

    parts.join(", ")
  end

  def save_status(status, message, results: nil)
    Setting.set("delete_experience.status", status)
    Setting.set("delete_experience.message", message)
    Setting.set("delete_experience.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[DeleteExperienceJob] Could not save status: #{e.message}"
  end
end
