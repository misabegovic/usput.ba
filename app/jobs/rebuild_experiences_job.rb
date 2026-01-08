# frozen_string_literal: true

# Background job for analyzing and rebuilding experiences that have quality issues
# or are too similar to other experiences
#
# Usage:
#   RebuildExperiencesJob.perform_later                          # Analyze and rebuild
#   RebuildExperiencesJob.perform_later(dry_run: true)           # Preview only
#   RebuildExperiencesJob.perform_later(rebuild_mode: "quality") # Only quality issues
#   RebuildExperiencesJob.perform_later(rebuild_mode: "similar") # Only similar experiences
#   RebuildExperiencesJob.perform_later(max_rebuilds: 10)        # Limit rebuilds
class RebuildExperiencesJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on Ai::OpenaiQueue::ConfigurationError if defined?(Ai::OpenaiQueue::ConfigurationError)

  # Rebuild modes
  MODES = %w[all quality similar accommodations].freeze

  def perform(dry_run: false, rebuild_mode: "all", max_rebuilds: nil, delete_similar: false)
    Rails.logger.info "[RebuildExperiencesJob] Starting (dry_run: #{dry_run}, mode: #{rebuild_mode}, max_rebuilds: #{max_rebuilds})"

    save_status("in_progress", "Starting experience analysis...")

    results = {
      started_at: Time.current,
      dry_run: dry_run,
      rebuild_mode: rebuild_mode,
      max_rebuilds: max_rebuilds,
      total_analyzed: 0,
      issues_found: 0,
      similar_pairs_found: 0,
      experiences_rebuilt: 0,
      experiences_deleted: 0,
      accommodation_locations_removed: 0,
      errors: [],
      analysis_report: nil
    }

    begin
      # Phase 1: Analyze all experiences
      save_status("in_progress", "Analyzing experiences for quality issues...")
      analyzer = Ai::ExperienceAnalyzer.new
      report = analyzer.generate_report

      results[:total_analyzed] = report[:total_experiences]
      results[:issues_found] = report[:experiences_with_issues]
      results[:similar_pairs_found] = report[:similar_experience_pairs]
      results[:experiences_to_delete_count] = report[:experiences_to_delete]
      results[:analysis_report] = report

      save_status("in_progress", "Found #{results[:issues_found]} experiences with issues, #{results[:similar_pairs_found]} similar pairs, #{report[:experiences_to_delete]} to delete")

      if dry_run
        # In dry run mode, just return the analysis without making changes
        results[:status] = "completed"
        results[:finished_at] = Time.current
        save_status("completed", "Analysis complete (preview mode - no changes made)", results: results)
        return results
      end

      # Phase 2: Delete experiences that don't make sense to regenerate
      experiences_to_delete = report[:deletable_experiences] || []
      if experiences_to_delete.any?
        save_status("in_progress", "Deleting #{experiences_to_delete.count} unsalvageable experiences...")

        experiences_to_delete.each do |exp_result|
          begin
            experience = Experience.find_by(id: exp_result[:experience_id])
            if experience
              Rails.logger.info "[RebuildExperiencesJob] Deleting unsalvageable experience #{experience.id}: #{experience.title} (reason: #{exp_result[:delete_reason]})"
              experience.destroy!
              results[:experiences_deleted] += 1
            end
          rescue StandardError => e
            results[:errors] << {
              experience_id: exp_result[:experience_id],
              title: exp_result[:title],
              action: "delete",
              error: e.message
            }
            Rails.logger.warn "[RebuildExperiencesJob] Error deleting #{exp_result[:title]}: #{e.message}"
          end
        end
      end

      # Phase 3: Handle experiences based on mode
      rebuild_count = 0
      max_to_rebuild = max_rebuilds || Float::INFINITY

      case rebuild_mode
      when "all", "quality"
        # Rebuild experiences with quality issues
        experiences_to_rebuild = report[:worst_experiences] || []

        experiences_to_rebuild.each do |exp_result|
          break if rebuild_count >= max_to_rebuild

          begin
            save_status("in_progress", "Rebuilding experience #{exp_result[:title]}...")
            success = rebuild_experience(exp_result[:experience_id], exp_result[:issues])

            if success
              rebuild_count += 1
              results[:experiences_rebuilt] += 1
            end
          rescue StandardError => e
            results[:errors] << {
              experience_id: exp_result[:experience_id],
              title: exp_result[:title],
              action: "rebuild",
              error: e.message
            }
            Rails.logger.warn "[RebuildExperiencesJob] Error rebuilding #{exp_result[:title]}: #{e.message}"
          end
        end
      end

      if rebuild_mode == "all" || rebuild_mode == "similar"
        # Handle similar experiences
        similar_pairs = report[:similar_experiences] || []

        similar_pairs.each do |pair|
          break if rebuild_count >= max_to_rebuild

          begin
            case pair[:recommendation]
            when :merge_or_delete_duplicate
              if delete_similar
                save_status("in_progress", "Removing duplicate experience...")
                delete_worse_experience(pair)
                results[:experiences_deleted] += 1
              else
                save_status("in_progress", "Differentiating similar experience...")
                differentiate_experience(pair)
                rebuild_count += 1
                results[:experiences_rebuilt] += 1
              end
            when :review_for_differentiation, :rename_for_clarity
              save_status("in_progress", "Differentiating similar experience...")
              differentiate_experience(pair)
              rebuild_count += 1
              results[:experiences_rebuilt] += 1
            end
          rescue StandardError => e
            results[:errors] << {
              pair: "#{pair[:experience_1][:id]} vs #{pair[:experience_2][:id]}",
              error: e.message
            }
            Rails.logger.warn "[RebuildExperiencesJob] Error handling similar pair: #{e.message}"
          end
        end
      end

      # Phase 4: Remove accommodation locations from experiences
      if rebuild_mode == "all" || rebuild_mode == "accommodations"
        save_status("in_progress", "Removing accommodation locations from experiences...")
        accommodation_removal_count = remove_accommodation_locations_from_experiences(dry_run: dry_run)
        results[:accommodation_locations_removed] = accommodation_removal_count
      end

      results[:status] = "completed"
      results[:finished_at] = Time.current

      save_status(
        "completed",
        "Completed: #{results[:experiences_rebuilt]} rebuilt, #{results[:experiences_deleted]} deleted, #{results[:accommodation_locations_removed]} accommodation locations removed, #{results[:errors].count} errors",
        results: results
      )

      Rails.logger.info "[RebuildExperiencesJob] Completed: #{results}"
      results

    rescue StandardError => e
      results[:status] = "failed"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("failed", e.message, results: results)
      Rails.logger.error "[RebuildExperiencesJob] Failed: #{e.message}"
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("rebuild_experiences.status", default: "idle"),
      message: Setting.get("rebuild_experiences.message", default: nil),
      results: JSON.parse(Setting.get("rebuild_experiences.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("rebuild_experiences.status", "idle")
    Setting.set("rebuild_experiences.message", nil)
    Setting.set("rebuild_experiences.results", "{}")
  end

  # Force reset a stuck or in-progress job back to idle
  def self.force_reset!
    Setting.set("rebuild_experiences.status", "idle")
    Setting.set("rebuild_experiences.message", "Force reset by admin")
  end

  private

  def rebuild_experience(experience_id, issues)
    experience = Experience.includes(:locations, :translations, :experience_category).find_by(id: experience_id)
    return false unless experience

    locations = experience.locations.to_a
    return false if locations.empty?

    # Determine what needs to be regenerated
    needs_new_content = issues.any? { |i| [:missing_description, :short_description, :ekavica_violation, :missing_translation].include?(i[:type]) }

    if needs_new_content
      regenerate_experience_content(experience, locations, issues)
    end

    true
  end

  def regenerate_experience_content(experience, locations, issues)
    Rails.logger.info "[RebuildExperiencesJob] Regenerating content for experience #{experience.id}: #{experience.title}"

    prompt = build_regeneration_prompt(experience, locations, issues)

    result = Ai::OpenaiQueue.request(
      prompt: prompt,
      schema: regeneration_schema,
      context: "RebuildExperiences:#{experience.id}"
    )

    return false unless result

    # Update translations
    supported_locales.each do |locale|
      title = result.dig(:titles, locale.to_s) || result.dig(:titles, locale.to_sym)
      description = result.dig(:descriptions, locale.to_s) || result.dig(:descriptions, locale.to_sym)

      experience.set_translation(:title, title, locale) if title.present?
      experience.set_translation(:description, description, locale) if description.present?
    end

    # Update duration if provided
    if result[:estimated_duration].present?
      experience.estimated_duration = result[:estimated_duration]
    end

    experience.save!
    Rails.logger.info "[RebuildExperiencesJob] Successfully regenerated content for experience #{experience.id}"
    true
  rescue Ai::OpenaiQueue::RequestError => e
    Rails.logger.warn "[RebuildExperiencesJob] AI regeneration failed: #{e.message}"
    false
  end

  def differentiate_experience(pair)
    # Find the experience with lower quality score to differentiate
    exp1 = Experience.includes(:locations, :translations).find_by(id: pair[:experience_1][:id])
    exp2 = Experience.includes(:locations, :translations).find_by(id: pair[:experience_2][:id])

    return unless exp1 && exp2

    # Differentiate the newer/smaller experience
    exp_to_modify = exp1.locations.count <= exp2.locations.count ? exp1 : exp2
    other_exp = exp_to_modify == exp1 ? exp2 : exp1

    Rails.logger.info "[RebuildExperiencesJob] Differentiating experience #{exp_to_modify.id} from #{other_exp.id}"

    prompt = build_differentiation_prompt(exp_to_modify, other_exp)

    result = Ai::OpenaiQueue.request(
      prompt: prompt,
      schema: regeneration_schema,
      context: "RebuildExperiences:differentiate:#{exp_to_modify.id}"
    )

    return unless result

    # Update translations with new differentiated content
    supported_locales.each do |locale|
      title = result.dig(:titles, locale.to_s) || result.dig(:titles, locale.to_sym)
      description = result.dig(:descriptions, locale.to_s) || result.dig(:descriptions, locale.to_sym)

      exp_to_modify.set_translation(:title, title, locale) if title.present?
      exp_to_modify.set_translation(:description, description, locale) if description.present?
    end

    exp_to_modify.save!
    Rails.logger.info "[RebuildExperiencesJob] Successfully differentiated experience #{exp_to_modify.id}"
  rescue Ai::OpenaiQueue::RequestError => e
    Rails.logger.warn "[RebuildExperiencesJob] AI differentiation failed: #{e.message}"
  end

  def delete_worse_experience(pair)
    # Delete the experience with fewer locations or lower quality
    exp1 = Experience.find_by(id: pair[:experience_1][:id])
    exp2 = Experience.find_by(id: pair[:experience_2][:id])

    return unless exp1 && exp2

    # Keep the one with more locations, or if equal, the older one
    exp_to_delete = if exp1.locations.count < exp2.locations.count
                      exp1
                    elsif exp2.locations.count < exp1.locations.count
                      exp2
                    elsif exp1.created_at > exp2.created_at
                      exp1
                    else
                      exp2
                    end

    Rails.logger.info "[RebuildExperiencesJob] Deleting duplicate experience #{exp_to_delete.id}: #{exp_to_delete.title}"
    exp_to_delete.destroy!
  end

  # Remove EXCESS accommodation locations from experiences
  # Some accommodation is OK (if it has special value), but too much indicates poor curation
  # This only removes accommodation from experiences where more than 50% of locations are accommodation
  # @param dry_run [Boolean] If true, just count but don't actually remove
  # @return [Integer] Number of accommodation locations removed
  def remove_accommodation_locations_from_experiences(dry_run: false)
    analyzer = Ai::ExperienceAnalyzer.new
    removed_count = 0

    Experience.includes(locations: :location_categories).find_each do |experience|
      total_locations = experience.locations.count
      next if total_locations == 0

      accommodation_locations = experience.locations.select do |location|
        analyzer.send(:accommodation_location?, location)
      end

      accommodation_count = accommodation_locations.count
      next if accommodation_count == 0

      accommodation_ratio = accommodation_count.to_f / total_locations

      # Only process experiences with too many accommodations (>50%) or only-accommodation experiences
      next unless accommodation_ratio > 0.5 || (total_locations == 1 && accommodation_count == 1)

      # For experiences with excess accommodation, remove enough to get below 50%
      # Keep at least one accommodation if the experience would otherwise be empty
      non_accommodation_count = total_locations - accommodation_count
      target_accommodation_count = if non_accommodation_count == 0
                                     1 # Keep one if there are no other locations
                                   else
                                     # Keep at most 1 accommodation, or enough to stay under 50%
                                     [1, (non_accommodation_count * 0.5).floor].max
                                   end

      accommodations_to_remove = accommodation_count - target_accommodation_count
      next if accommodations_to_remove <= 0

      # Remove excess accommodations (keep the first one in case it has special value)
      accommodation_locations.drop(target_accommodation_count).each do |location|
        if dry_run
          Rails.logger.info "[RebuildExperiencesJob] Would remove excess accommodation '#{location.name}' from experience '#{experience.title}'"
        else
          Rails.logger.info "[RebuildExperiencesJob] Removing excess accommodation '#{location.name}' from experience '#{experience.title}'"
          experience.experience_locations.find_by(location: location)&.destroy
        end
        removed_count += 1
      end

      # If experience has no locations left after removal, delete the experience
      experience.reload unless dry_run
      if !dry_run && experience.locations.count == 0
        Rails.logger.info "[RebuildExperiencesJob] Deleting experience '#{experience.title}' - no locations left after accommodation removal"
        experience.destroy
      end
    end

    Rails.logger.info "[RebuildExperiencesJob] #{dry_run ? 'Would remove' : 'Removed'} #{removed_count} excess accommodation locations from experiences"
    removed_count
  end

  def build_regeneration_prompt(experience, locations, issues)
    locations_info = locations.map do |loc|
      "- #{loc.name} (#{loc.city}): #{loc.description.to_s.truncate(100)}"
    end.join("\n")

    issue_descriptions = issues.map { |i| "- #{i[:message]}" }.join("\n")

    <<~PROMPT
      #{cultural_context}

      ---

      TASK: Regenerate content for an existing tourism experience that has quality issues.

      CURRENT EXPERIENCE:
      Title: #{experience.title}
      City: #{experience.city}
      Current Description: #{experience.description.to_s.truncate(300)}

      LOCATIONS IN THIS EXPERIENCE:
      #{locations_info}

      QUALITY ISSUES TO FIX:
      #{issue_descriptions}

      REQUIREMENTS:
      1. Create NEW, high-quality titles and descriptions for all languages
      2. Titles should be evocative and specific to this experience, NOT generic
      3. Descriptions should be 100-200 words, rich and engaging
      4. If the experience is in Bosnia, use authentic Bosnian cultural references

      ⚠️ KRITIČNO ZA BOSANSKI JEZIK ("bs"):
      - OBAVEZNO koristiti IJEKAVICU: "lijepo", "vrijeme", "mjesto", "vidjeti", "bijelo", "stoljeća"
      - NIKAD ekavicu: NE "lepo", "vreme", "mesto", "videti", "belo", "stoleća"
      - Koristiti "historija" (NE "istorija"), "hiljada" (NE "tisuća")

      Languages to include: #{supported_locales.join(', ')}
      REMINDER: For "bs" (Bosnian) use IJEKAVICA, NOT ekavica!
    PROMPT
  end

  def build_differentiation_prompt(experience, similar_experience)
    <<~PROMPT
      #{cultural_context}

      ---

      TASK: Create NEW, DIFFERENTIATED content for an experience that is too similar to another.

      EXPERIENCE TO MODIFY:
      Title: #{experience.title}
      City: #{experience.city}
      Description: #{experience.description.to_s.truncate(300)}
      Locations: #{experience.locations.pluck(:name).join(', ')}

      SIMILAR EXPERIENCE (to differentiate FROM):
      Title: #{similar_experience.title}
      City: #{similar_experience.city}
      Description: #{similar_experience.description.to_s.truncate(300)}
      Locations: #{similar_experience.locations.pluck(:name).join(', ')}

      REQUIREMENTS:
      1. Create a UNIQUE title that clearly distinguishes this experience
      2. Focus on different aspects, themes, or perspectives
      3. If locations overlap, emphasize what makes THIS experience's approach unique
      4. Descriptions should be 100-200 words, highlighting the unique value

      ⚠️ KRITIČNO ZA BOSANSKI JEZIK ("bs"):
      - OBAVEZNO koristiti IJEKAVICU: "lijepo", "vrijeme", "mjesto", "vidjeti", "bijelo"
      - NIKAD ekavicu: NE "lepo", "vreme", "mesto", "videti", "belo"
      - Koristiti "historija" (NE "istorija"), "hiljada" (NE "tisuća")

      Languages to include: #{supported_locales.join(', ')}
    PROMPT
  end

  def regeneration_schema
    locale_properties = supported_locales.to_h { |loc| [loc, { type: "string" }] }

    {
      type: "object",
      properties: {
        titles: {
          type: "object",
          properties: locale_properties,
          required: supported_locales,
          additionalProperties: false
        },
        descriptions: {
          type: "object",
          properties: locale_properties,
          required: supported_locales,
          additionalProperties: false
        },
        estimated_duration: { type: "integer" }
      },
      required: %w[titles descriptions estimated_duration],
      additionalProperties: false
    }
  end

  def cultural_context
    Ai::ExperienceGenerator::BIH_CULTURAL_CONTEXT
  end

  def supported_locales
    @supported_locales ||= Locale.ai_supported_codes.presence ||
      %w[en bs hr de es fr it pt nl pl cs sk sl sr]
  end

  def save_status(status, message, results: nil)
    Setting.set("rebuild_experiences.status", status)
    Setting.set("rebuild_experiences.message", message)
    Setting.set("rebuild_experiences.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[RebuildExperiencesJob] Could not save status: #{e.message}"
  end
end
