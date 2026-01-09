# frozen_string_literal: true

# Job to regenerate translations and audio tours for resources marked as dirty.
# This is triggered from the Admin Dashboard when curated content changes are approved.
#
# Processes:
# - Locations: Regenerates descriptions, historical_context translations + audio tours
# - Experiences: Regenerates title and description translations
# - Plans: Regenerates title and notes translations
class RegenerateTranslationsJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient errors
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  # Status tracking via Settings
  STATUS_KEY = "regenerate_translations.status"
  PROGRESS_KEY = "regenerate_translations.progress"

  def perform(options = {})
    @dry_run = options[:dry_run] || false
    @include_audio = options.fetch(:include_audio, true)
    @results = { locations: { success: 0, failed: 0 }, experiences: { success: 0, failed: 0 }, plans: { success: 0, failed: 0 } }

    update_status("in_progress", "Starting regeneration job...")

    begin
      process_dirty_locations
      process_dirty_experiences
      process_dirty_plans

      update_status("completed", "Regeneration complete", results: @results)
      Rails.logger.info "[RegenerateTranslationsJob] Complete: #{@results.inspect}"
    rescue => e
      update_status("failed", "Error: #{e.message}")
      raise
    end
  end

  def self.status
    Setting.get(STATUS_KEY, default: "idle")
  end

  def self.progress
    JSON.parse(Setting.get(PROGRESS_KEY, default: "{}"))
  rescue JSON::ParserError
    {}
  end

  def self.reset_status!
    Setting.set(STATUS_KEY, "idle")
    Setting.set(PROGRESS_KEY, "{}")
  end

  def self.in_progress?
    status == "in_progress"
  end

  def self.dirty_counts
    {
      locations: Location.needs_ai_regeneration.count,
      experiences: Experience.needs_ai_regeneration.count,
      plans: Plan.needs_ai_regeneration.count
    }
  end

  private

  def process_dirty_locations
    locations = Location.needs_ai_regeneration
    total = locations.count
    update_progress("Locations", 0, total)

    return if total.zero?

    Rails.logger.info "[RegenerateTranslationsJob] Processing #{total} dirty locations"

    enricher = Ai::LocationEnricher.new

    locations.find_each.with_index do |location, index|
      begin
        Rails.logger.info "[RegenerateTranslationsJob] Regenerating location #{index + 1}/#{total}: #{location.name}"

        unless @dry_run
          # Regenerate translations
          enricher.enrich(location)

          # Regenerate audio tours in all default locales
          if @include_audio
            regenerate_audio_tours(location)
          end

          # Mark as processed
          location.update_column(:needs_ai_regeneration, false)
        end

        @results[:locations][:success] += 1
        update_progress("Locations", index + 1, total)
      rescue => e
        Rails.logger.error "[RegenerateTranslationsJob] Failed to regenerate location #{location.id}: #{e.message}"
        @results[:locations][:failed] += 1
      end
    end
  end

  def process_dirty_experiences
    experiences = Experience.needs_ai_regeneration
    total = experiences.count
    update_progress("Experiences", 0, total)

    return if total.zero?

    Rails.logger.info "[RegenerateTranslationsJob] Processing #{total} dirty experiences"

    experiences.find_each.with_index do |experience, index|
      begin
        Rails.logger.info "[RegenerateTranslationsJob] Regenerating experience #{index + 1}/#{total}: #{experience.title}"

        unless @dry_run
          regenerate_experience_translations(experience)
          experience.update_column(:needs_ai_regeneration, false)
        end

        @results[:experiences][:success] += 1
        update_progress("Experiences", index + 1, total)
      rescue => e
        Rails.logger.error "[RegenerateTranslationsJob] Failed to regenerate experience #{experience.id}: #{e.message}"
        @results[:experiences][:failed] += 1
      end
    end
  end

  def process_dirty_plans
    plans = Plan.needs_ai_regeneration
    total = plans.count
    update_progress("Plans", 0, total)

    return if total.zero?

    Rails.logger.info "[RegenerateTranslationsJob] Processing #{total} dirty plans"

    plans.find_each.with_index do |plan, index|
      begin
        Rails.logger.info "[RegenerateTranslationsJob] Regenerating plan #{index + 1}/#{total}: #{plan.title}"

        unless @dry_run
          regenerate_plan_translations(plan)
          plan.update_column(:needs_ai_regeneration, false)
        end

        @results[:plans][:success] += 1
        update_progress("Plans", index + 1, total)
      rescue => e
        Rails.logger.error "[RegenerateTranslationsJob] Failed to regenerate plan #{plan.id}: #{e.message}"
        @results[:plans][:failed] += 1
      end
    end
  end

  def regenerate_audio_tours(location)
    generator = Ai::AudioTourGenerator.new(location)

    # Generate audio tours for default locales
    default_locales.each do |locale|
      begin
        Rails.logger.info "[RegenerateTranslationsJob] Generating audio tour for #{location.name} in #{locale}"
        generator.generate(locale: locale, force: true)
      rescue => e
        Rails.logger.warn "[RegenerateTranslationsJob] Failed to generate audio for #{location.name} in #{locale}: #{e.message}"
      end
    end
  end

  def regenerate_experience_translations(experience)
    # Use AI to regenerate title and description translations
    supported_locales.each_slice(5) do |locale_batch|
      translations = generate_experience_translations_batch(experience, locale_batch)
      next unless translations

      locale_batch.each do |locale|
        if translations.dig(locale.to_s, "title")
          experience.set_translation(:title, translations.dig(locale.to_s, "title"), locale)
        end
        if translations.dig(locale.to_s, "description")
          experience.set_translation(:description, translations.dig(locale.to_s, "description"), locale)
        end
      end
    end

    experience.save!
  end

  def regenerate_plan_translations(plan)
    # Use AI to regenerate title and notes translations
    supported_locales.each_slice(5) do |locale_batch|
      translations = generate_plan_translations_batch(plan, locale_batch)
      next unless translations

      locale_batch.each do |locale|
        if translations.dig(locale.to_s, "title")
          plan.set_translation(:title, translations.dig(locale.to_s, "title"), locale)
        end
        if translations.dig(locale.to_s, "notes")
          plan.set_translation(:notes, translations.dig(locale.to_s, "notes"), locale)
        end
      end
    end

    plan.save!
  end

  def generate_experience_translations_batch(experience, locales)
    prompt = <<~PROMPT
      Translate the following experience information into these languages: #{locales.join(', ')}.

      Experience Title (original): #{experience.title}
      Experience Description (original): #{experience.description}
      Category: #{experience.experience_category&.name}
      Locations: #{experience.locations.map(&:name).join(', ')}

      Requirements:
      - Create culturally appropriate, engaging translations
      - For Bosnian (bs): Use ijekavica, not ekavica. Use "historija" not "istorija".
      - Each title should be evocative and poetic where appropriate
      - Each description should be 100-200 words, capturing the spirit of the journey

      Return a JSON object with this structure:
      {
        "locale_code": {
          "title": "translated title",
          "description": "translated description"
        }
      }
    PROMPT

    response = Ai::OpenaiQueue.chat(
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
      context: "RegenerateTranslationsJob:experience"
    )

    JSON.parse(response)
  rescue => e
    Rails.logger.error "[RegenerateTranslationsJob] Experience translation failed: #{e.message}"
    nil
  end

  def generate_plan_translations_batch(plan, locales)
    experiences_info = plan.plan_experiences.includes(:experience).map do |pe|
      "Day #{pe.day_number}: #{pe.experience.title}"
    end.join("\n")

    prompt = <<~PROMPT
      Translate the following travel plan information into these languages: #{locales.join(', ')}.

      Plan Title (original): #{plan.title}
      Plan Notes (original): #{plan.notes}
      City: #{plan.city_name}
      Duration: #{plan.duration_in_days} days
      Experiences:
      #{experiences_info}

      Requirements:
      - Create culturally appropriate, engaging translations
      - For Bosnian (bs): Use ijekavica, not ekavica.
      - Title should be evocative and capture the essence of the journey
      - Notes should be helpful travel tips (50-100 words)

      Return a JSON object with this structure:
      {
        "locale_code": {
          "title": "translated title",
          "notes": "translated notes"
        }
      }
    PROMPT

    response = Ai::OpenaiQueue.chat(
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
      context: "RegenerateTranslationsJob:plan"
    )

    JSON.parse(response)
  rescue => e
    Rails.logger.error "[RegenerateTranslationsJob] Plan translation failed: #{e.message}"
    nil
  end

  def supported_locales
    @supported_locales ||= Translation::SUPPORTED_LOCALES
  end

  def default_locales
    # Default locales for audio tour generation
    %w[bs en de]
  end

  def update_status(status, message, results: nil)
    Setting.set(STATUS_KEY, status)
    progress = { message: message, updated_at: Time.current.iso8601 }
    progress[:results] = results if results
    Setting.set(PROGRESS_KEY, progress.to_json)
  end

  def update_progress(resource_type, current, total)
    progress = self.class.progress
    progress["current_type"] = resource_type
    progress["current"] = current
    progress["total"] = total
    progress["updated_at"] = Time.current.iso8601
    Setting.set(PROGRESS_KEY, progress.to_json)
  end
end
