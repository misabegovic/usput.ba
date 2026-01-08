# frozen_string_literal: true

# Background job for analyzing and rebuilding plans that have quality issues
# or are too similar to other plans
#
# Usage:
#   RebuildPlansJob.perform_later                          # Analyze and rebuild
#   RebuildPlansJob.perform_later(dry_run: true)           # Preview only
#   RebuildPlansJob.perform_later(rebuild_mode: "quality") # Only quality issues
#   RebuildPlansJob.perform_later(rebuild_mode: "similar") # Only similar plans
#   RebuildPlansJob.perform_later(max_rebuilds: 10)        # Limit rebuilds
class RebuildPlansJob < ApplicationJob
  queue_as :ai_generation

  # Retry on transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry on configuration errors
  discard_on Ai::OpenaiQueue::ConfigurationError if defined?(Ai::OpenaiQueue::ConfigurationError)

  # Rebuild modes
  MODES = %w[all quality similar].freeze

  def perform(dry_run: false, rebuild_mode: "all", max_rebuilds: nil, delete_similar: false)
    Rails.logger.info "[RebuildPlansJob] Starting (dry_run: #{dry_run}, mode: #{rebuild_mode}, max_rebuilds: #{max_rebuilds})"

    save_status("in_progress", "Starting plan analysis...")

    results = {
      started_at: Time.current,
      dry_run: dry_run,
      rebuild_mode: rebuild_mode,
      max_rebuilds: max_rebuilds,
      total_analyzed: 0,
      issues_found: 0,
      similar_pairs_found: 0,
      plans_to_delete_count: 0,
      plans_rebuilt: 0,
      plans_deleted: 0,
      errors: [],
      analysis_report: nil
    }

    begin
      # Phase 1: Analyze all plans
      save_status("in_progress", "Analyzing plans for quality issues...")
      analyzer = Ai::PlanAnalyzer.new
      report = analyzer.generate_report

      results[:total_analyzed] = report[:total_plans]
      results[:issues_found] = report[:plans_with_issues]
      results[:similar_pairs_found] = report[:similar_plan_pairs]
      results[:plans_to_delete_count] = report[:plans_to_delete]
      results[:analysis_report] = report

      save_status("in_progress", "Found #{results[:issues_found]} plans with issues, #{results[:similar_pairs_found]} similar pairs, #{report[:plans_to_delete]} to delete")

      if dry_run
        # In dry run mode, just return the analysis without making changes
        results[:status] = "completed"
        results[:finished_at] = Time.current
        save_status("completed", "Analysis complete (preview mode - no changes made)", results: results)
        return results
      end

      # Phase 2: Delete plans that don't make sense to regenerate
      plans_to_delete = report[:deletable_plans] || []
      if plans_to_delete.any?
        save_status("in_progress", "Deleting #{plans_to_delete.count} unsalvageable plans...")

        plans_to_delete.each do |plan_result|
          begin
            plan = Plan.find_by(id: plan_result[:plan_id])
            if plan
              Rails.logger.info "[RebuildPlansJob] Deleting unsalvageable plan #{plan.id}: #{plan.title} (reason: #{plan_result[:delete_reason]})"
              plan.destroy!
              results[:plans_deleted] += 1
            end
          rescue StandardError => e
            results[:errors] << {
              plan_id: plan_result[:plan_id],
              title: plan_result[:title],
              action: "delete",
              error: e.message
            }
            Rails.logger.warn "[RebuildPlansJob] Error deleting #{plan_result[:title]}: #{e.message}"
          end
        end
      end

      # Phase 3: Handle plans based on mode
      rebuild_count = 0
      max_to_rebuild = max_rebuilds || Float::INFINITY

      case rebuild_mode
      when "all", "quality"
        # Rebuild plans with quality issues
        plans_to_rebuild = report[:worst_plans] || []

        plans_to_rebuild.each do |plan_result|
          break if rebuild_count >= max_to_rebuild

          begin
            save_status("in_progress", "Rebuilding plan #{plan_result[:title]}...")
            success = rebuild_plan(plan_result[:plan_id], plan_result[:issues])

            if success
              rebuild_count += 1
              results[:plans_rebuilt] += 1
            end
          rescue StandardError => e
            results[:errors] << {
              plan_id: plan_result[:plan_id],
              title: plan_result[:title],
              action: "rebuild",
              error: e.message
            }
            Rails.logger.warn "[RebuildPlansJob] Error rebuilding #{plan_result[:title]}: #{e.message}"
          end
        end
      end

      if rebuild_mode == "all" || rebuild_mode == "similar"
        # Handle similar plans
        similar_pairs = report[:similar_plans] || []

        similar_pairs.each do |pair|
          break if rebuild_count >= max_to_rebuild

          begin
            case pair[:recommendation]
            when :delete_duplicate_profile, :merge_or_delete_duplicate
              if delete_similar
                save_status("in_progress", "Removing duplicate plan...")
                delete_worse_plan(pair)
                results[:plans_deleted] += 1
              else
                save_status("in_progress", "Differentiating similar plan...")
                differentiate_plan(pair)
                rebuild_count += 1
                results[:plans_rebuilt] += 1
              end
            when :rename_for_clarity
              save_status("in_progress", "Differentiating similar plan...")
              differentiate_plan(pair)
              rebuild_count += 1
              results[:plans_rebuilt] += 1
            end
          rescue StandardError => e
            results[:errors] << {
              pair: "#{pair[:plan_1][:id]} vs #{pair[:plan_2][:id]}",
              error: e.message
            }
            Rails.logger.warn "[RebuildPlansJob] Error handling similar pair: #{e.message}"
          end
        end
      end

      results[:status] = "completed"
      results[:finished_at] = Time.current

      save_status(
        "completed",
        "Completed: #{results[:plans_rebuilt]} rebuilt, #{results[:plans_deleted]} deleted, #{results[:errors].count} errors",
        results: results
      )

      Rails.logger.info "[RebuildPlansJob] Completed: #{results}"
      results

    rescue StandardError => e
      results[:status] = "failed"
      results[:error] = e.message
      results[:finished_at] = Time.current
      save_status("failed", e.message, results: results)
      Rails.logger.error "[RebuildPlansJob] Failed: #{e.message}"
      raise
    end
  end

  # Returns current status of the job
  def self.current_status
    {
      status: Setting.get("rebuild_plans.status", default: "idle"),
      message: Setting.get("rebuild_plans.message", default: nil),
      results: JSON.parse(Setting.get("rebuild_plans.results", default: "{}") || "{}")
    }
  rescue JSON::ParserError
    { status: "idle", message: nil, results: {} }
  end

  # Clear any existing status
  def self.clear_status!
    Setting.set("rebuild_plans.status", "idle")
    Setting.set("rebuild_plans.message", nil)
    Setting.set("rebuild_plans.results", "{}")
  end

  # Force reset a stuck or in-progress job back to idle
  def self.force_reset!
    Setting.set("rebuild_plans.status", "idle")
    Setting.set("rebuild_plans.message", "Force reset by admin")
  end

  private

  def rebuild_plan(plan_id, issues)
    plan = Plan.includes(:plan_experiences, :experiences, :translations).find_by(id: plan_id)
    return false unless plan

    # Skip user-owned plans
    return false if plan.user_id.present?

    experiences = plan.experiences.to_a
    return false if experiences.empty?

    # Determine what needs to be regenerated
    needs_new_content = issues.any? { |i| [:missing_title, :short_title, :ekavica_violation, :missing_translation, :missing_notes, :short_notes].include?(i[:type]) }

    if needs_new_content
      regenerate_plan_content(plan, experiences, issues)
    end

    true
  end

  def regenerate_plan_content(plan, experiences, issues)
    Rails.logger.info "[RebuildPlansJob] Regenerating content for plan #{plan.id}: #{plan.title}"

    prompt = build_regeneration_prompt(plan, experiences, issues)

    result = Ai::OpenaiQueue.request(
      prompt: prompt,
      schema: regeneration_schema,
      context: "RebuildPlans:#{plan.id}"
    )

    return false unless result

    # Update translations
    supported_locales.each do |locale|
      title = result.dig(:titles, locale.to_s) || result.dig(:titles, locale.to_sym)
      notes = result.dig(:notes, locale.to_s) || result.dig(:notes, locale.to_sym)

      plan.set_translation(:title, title, locale) if title.present?
      plan.set_translation(:notes, notes, locale) if notes.present?
    end

    plan.save!
    Rails.logger.info "[RebuildPlansJob] Successfully regenerated content for plan #{plan.id}"
    true
  rescue Ai::OpenaiQueue::RequestError => e
    Rails.logger.warn "[RebuildPlansJob] AI regeneration failed: #{e.message}"
    false
  end

  def differentiate_plan(pair)
    # Find the plan with lower quality score to differentiate
    plan1 = Plan.includes(:plan_experiences, :translations).find_by(id: pair[:plan_1][:id])
    plan2 = Plan.includes(:plan_experiences, :translations).find_by(id: pair[:plan_2][:id])

    return unless plan1 && plan2

    # Differentiate the newer/smaller plan
    plan_to_modify = plan1.plan_experiences.count <= plan2.plan_experiences.count ? plan1 : plan2
    other_plan = plan_to_modify == plan1 ? plan2 : plan1

    Rails.logger.info "[RebuildPlansJob] Differentiating plan #{plan_to_modify.id} from #{other_plan.id}"

    prompt = build_differentiation_prompt(plan_to_modify, other_plan)

    result = Ai::OpenaiQueue.request(
      prompt: prompt,
      schema: regeneration_schema,
      context: "RebuildPlans:differentiate:#{plan_to_modify.id}"
    )

    return unless result

    # Update translations with new differentiated content
    supported_locales.each do |locale|
      title = result.dig(:titles, locale.to_s) || result.dig(:titles, locale.to_sym)
      notes = result.dig(:notes, locale.to_s) || result.dig(:notes, locale.to_sym)

      plan_to_modify.set_translation(:title, title, locale) if title.present?
      plan_to_modify.set_translation(:notes, notes, locale) if notes.present?
    end

    plan_to_modify.save!
    Rails.logger.info "[RebuildPlansJob] Successfully differentiated plan #{plan_to_modify.id}"
  rescue Ai::OpenaiQueue::RequestError => e
    Rails.logger.warn "[RebuildPlansJob] AI differentiation failed: #{e.message}"
  end

  def delete_worse_plan(pair)
    # Delete the plan with fewer experiences or lower quality
    plan1 = Plan.find_by(id: pair[:plan_1][:id])
    plan2 = Plan.find_by(id: pair[:plan_2][:id])

    return unless plan1 && plan2

    # Keep the one with more experiences, or if equal, the older one
    plan_to_delete = if plan1.plan_experiences.count < plan2.plan_experiences.count
                       plan1
                     elsif plan2.plan_experiences.count < plan1.plan_experiences.count
                       plan2
                     elsif plan1.created_at > plan2.created_at
                       plan1
                     else
                       plan2
                     end

    Rails.logger.info "[RebuildPlansJob] Deleting duplicate plan #{plan_to_delete.id}: #{plan_to_delete.title}"
    plan_to_delete.destroy!
  end

  def build_regeneration_prompt(plan, experiences, issues)
    experiences_info = experiences.map do |exp|
      "- #{exp.title} (#{exp.formatted_duration || 'duration unknown'})"
    end.join("\n")

    issue_descriptions = issues.map { |i| "- #{i[:message]}" }.join("\n")

    profile = plan.preferences&.dig("tourist_profile") || "general"

    <<~PROMPT
      #{cultural_context}

      ---

      TASK: Regenerate content for an existing travel plan that has quality issues.

      CURRENT PLAN:
      Title: #{plan.title}
      City: #{plan.city_name}
      Tourist Profile: #{profile}
      Duration: #{plan.calculated_duration_days} days

      EXPERIENCES IN THIS PLAN:
      #{experiences_info}

      QUALITY ISSUES TO FIX:
      #{issue_descriptions}

      REQUIREMENTS:
      1. Create NEW, high-quality titles and notes for all languages
      2. Titles should be evocative and specific to this plan, NOT generic
      3. Notes should be 50-150 words with practical travel tips
      4. Match the #{profile} tourist profile

      ⚠️ KRITIČNO ZA BOSANSKI JEZIK ("bs"):
      - OBAVEZNO koristiti IJEKAVICU: "lijepo", "vrijeme", "mjesto", "vidjeti", "bijelo", "stoljeća"
      - NIKAD ekavicu: NE "lepo", "vreme", "mesto", "videti", "belo", "stoleća"
      - Koristiti "historija" (NE "istorija"), "hiljada" (NE "tisuća")

      Languages to include: #{supported_locales.join(', ')}
      REMINDER: For "bs" (Bosnian) use IJEKAVICA, NOT ekavica!
    PROMPT
  end

  def build_differentiation_prompt(plan, similar_plan)
    profile = plan.preferences&.dig("tourist_profile") || "general"

    <<~PROMPT
      #{cultural_context}

      ---

      TASK: Create NEW, DIFFERENTIATED content for a plan that is too similar to another.

      PLAN TO MODIFY:
      Title: #{plan.title}
      City: #{plan.city_name}
      Profile: #{profile}
      Experiences: #{plan.experiences.pluck(:title).join(', ')}

      SIMILAR PLAN (to differentiate FROM):
      Title: #{similar_plan.title}
      City: #{similar_plan.city_name}
      Profile: #{similar_plan.preferences&.dig("tourist_profile")}
      Experiences: #{similar_plan.experiences.pluck(:title).join(', ')}

      REQUIREMENTS:
      1. Create a UNIQUE title that clearly distinguishes this plan
      2. Focus on different aspects, themes, or perspectives
      3. Emphasize what makes THIS plan's approach unique for #{profile} travelers
      4. Notes should be 50-150 words, highlighting the unique value

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
        notes: {
          type: "object",
          properties: locale_properties,
          required: supported_locales,
          additionalProperties: false
        }
      },
      required: %w[titles notes],
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
    Setting.set("rebuild_plans.status", status)
    Setting.set("rebuild_plans.message", message)
    Setting.set("rebuild_plans.results", results.to_json) if results
  rescue StandardError => e
    Rails.logger.warn "[RebuildPlansJob] Could not save status: #{e.message}"
  end
end
