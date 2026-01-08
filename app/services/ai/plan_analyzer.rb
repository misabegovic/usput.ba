# frozen_string_literal: true

module Ai
  # Analyzes plans for quality issues and similarity to other plans
  # Used by RebuildPlansJob to determine which plans need regeneration
  class PlanAnalyzer
    include Concerns::ErrorReporting

    # Quality thresholds
    MIN_TITLE_LENGTH = 5
    MIN_NOTES_LENGTH = 50
    MIN_EXPERIENCES_COUNT = 1
    SIMILARITY_THRESHOLD = 0.7 # 70% title similarity considered too similar

    # Score below which a plan should be deleted rather than regenerated
    DELETE_THRESHOLD_SCORE = 20

    # Required locales for complete translations
    REQUIRED_LOCALES = %w[en bs].freeze

    def initialize
      @issues_by_type = Hash.new { |h, k| h[k] = [] }
    end

    # Analyze a single plan and return quality issues
    # @param plan [Plan] The plan to analyze
    # @return [Hash] Analysis results with issues found
    def analyze(plan)
      issues = []

      # Skip user-owned plans - only analyze AI-generated public plans
      if plan.user_id.present?
        return {
          plan_id: plan.id,
          title: plan.title,
          city: plan.city_name,
          issues: [],
          score: 100,
          needs_rebuild: false,
          should_delete: false,
          skipped: true,
          skip_reason: "User-owned plan"
        }
      end

      # Check title quality
      issues.concat(check_title_quality(plan))

      # Check notes quality
      issues.concat(check_notes_quality(plan))

      # Check translation completeness
      issues.concat(check_translations(plan))

      # Check experience count
      issues.concat(check_experiences(plan))

      # Check profile metadata
      issues.concat(check_profile_metadata(plan))

      score = calculate_quality_score(issues)
      should_delete = determine_should_delete(plan, issues, score)

      {
        plan_id: plan.id,
        title: plan.title,
        city: plan.city_name,
        profile: plan.preferences&.dig("tourist_profile"),
        issues: issues,
        score: score,
        needs_rebuild: !should_delete && issues.any? { |i| i[:severity] == :critical || i[:severity] == :high },
        should_delete: should_delete,
        delete_reason: should_delete ? explain_delete_reason(plan, issues, score) : nil
      }
    end

    # Analyze all plans and find quality issues
    # @return [Array<Hash>] Array of analysis results
    def analyze_all
      results = []

      Plan.includes(:plan_experiences, :experiences, :translations).find_each do |plan|
        result = analyze(plan)
        results << result unless result[:skipped]
      end

      results.sort_by { |r| r[:score] }
    end

    # Find plans that are too similar to each other
    # @return [Array<Hash>] Array of similarity groups
    def find_similar_plans
      similar_groups = []
      plans = Plan.where(user_id: nil).includes(:translations).to_a

      plans.each_with_index do |plan1, i|
        plans[(i + 1)..].each do |plan2|
          similarity = calculate_similarity(plan1, plan2)

          if similarity[:overall] >= SIMILARITY_THRESHOLD
            similar_groups << {
              plan_1: { id: plan1.id, title: plan1.title, city: plan1.city_name, profile: plan1.preferences&.dig("tourist_profile") },
              plan_2: { id: plan2.id, title: plan2.title, city: plan2.city_name, profile: plan2.preferences&.dig("tourist_profile") },
              similarity: similarity,
              recommendation: recommend_action(similarity, plan1, plan2)
            }
          end
        end
      end

      similar_groups.sort_by { |g| -g[:similarity][:overall] }
    end

    # Get a comprehensive report of all quality issues
    # @return [Hash] Report with statistics and issues by type
    def generate_report
      all_results = []

      Plan.includes(:plan_experiences, :experiences, :translations).find_each do |plan|
        result = analyze(plan)
        all_results << result unless result[:skipped]
      end

      similar_plans = find_similar_plans

      plans_to_delete = all_results.select { |r| r[:should_delete] }
      plans_to_rebuild = all_results.select { |r| r[:needs_rebuild] && !r[:should_delete] }

      {
        total_plans: all_results.count,
        plans_with_issues: all_results.count { |r| r[:issues].any? },
        plans_needing_rebuild: plans_to_rebuild.count,
        plans_to_delete: plans_to_delete.count,
        similar_plan_pairs: similar_plans.count,
        issues_by_severity: group_issues_by_severity(all_results),
        issues_by_type: group_issues_by_type(all_results),
        worst_plans: plans_to_rebuild.take(20),
        deletable_plans: plans_to_delete.take(20),
        similar_plans: similar_plans.take(10)
      }
    end

    private

    def check_title_quality(plan)
      issues = []

      title = plan.title.to_s
      if title.blank?
        issues << {
          type: :missing_title,
          severity: :critical,
          message: "Missing title"
        }
      elsif title.length < MIN_TITLE_LENGTH
        issues << {
          type: :short_title,
          severity: :high,
          message: "Title too short (#{title.length} chars)"
        }
      elsif generic_title?(title)
        issues << {
          type: :generic_title,
          severity: :medium,
          message: "Title appears generic or placeholder-like",
          title: title
        }
      end

      # Check Bosnian title for ekavica
      bs_title = plan.translation_for(:title, :bs).to_s
      if bs_title.present?
        ekavica_violations = detect_ekavica(bs_title)
        if ekavica_violations.any?
          issues << {
            type: :ekavica_violation,
            severity: :high,
            message: "Bosnian title uses ekavica instead of ijekavica",
            violations: ekavica_violations,
            locale: "bs"
          }
        end
      end

      issues
    end

    def check_notes_quality(plan)
      issues = []

      # Check English notes
      en_notes = plan.translation_for(:notes, :en).to_s
      if en_notes.blank?
        issues << {
          type: :missing_notes,
          severity: :medium,
          message: "Missing English travel notes",
          locale: "en"
        }
      elsif en_notes.length < MIN_NOTES_LENGTH
        issues << {
          type: :short_notes,
          severity: :low,
          message: "English notes too short (#{en_notes.length} chars, min: #{MIN_NOTES_LENGTH})",
          locale: "en",
          current_length: en_notes.length
        }
      end

      # Check Bosnian notes for ekavica
      bs_notes = plan.translation_for(:notes, :bs).to_s
      if bs_notes.present?
        ekavica_violations = detect_ekavica(bs_notes)
        if ekavica_violations.any?
          issues << {
            type: :ekavica_violation,
            severity: :high,
            message: "Bosnian notes use ekavica instead of ijekavica",
            violations: ekavica_violations.take(5),
            locale: "bs"
          }
        end
      end

      issues
    end

    def check_translations(plan)
      issues = []

      REQUIRED_LOCALES.each do |locale|
        title = plan.translation_for(:title, locale).to_s

        if title.blank?
          issues << {
            type: :missing_translation,
            severity: locale == "en" ? :critical : :medium,
            message: "Missing #{locale.upcase} title translation",
            locale: locale
          }
        end
      end

      issues
    end

    def check_experiences(plan)
      issues = []

      experience_count = plan.plan_experiences.count

      if experience_count == 0
        issues << {
          type: :no_experiences,
          severity: :critical,
          message: "Plan has no experiences"
        }
      elsif experience_count < MIN_EXPERIENCES_COUNT
        issues << {
          type: :few_experiences,
          severity: :medium,
          message: "Plan has only #{experience_count} experience(s), recommended: #{MIN_EXPERIENCES_COUNT}+",
          current_count: experience_count
        }
      end

      issues
    end

    def check_profile_metadata(plan)
      issues = []

      profile = plan.preferences&.dig("tourist_profile")
      if profile.blank?
        issues << {
          type: :missing_profile,
          severity: :low,
          message: "Plan has no tourist profile assigned"
        }
      end

      issues
    end

    def detect_ekavica(text)
      # Common ekavica words that should be ijekavica in Bosnian
      ekavica_patterns = {
        /\blepo\b/i => "lijepo",
        /\breka\b/i => "rijeka",
        /\bvreme\b/i => "vrijeme",
        /\bmesto\b/i => "mjesto",
        /\bvideti\b/i => "vidjeti",
        /\bdete\b/i => "dijete",
        /\bmleko\b/i => "mlijeko",
        /\bbelo\b/i => "bijelo",
        /\bpevati\b/i => "pjevati",
        /\bsvet\b/i => "svijet",
        /\bčovek\b/i => "čovjek",
        /\bdevojka\b/i => "djevojka",
        /\bdeca\b/i => "djeca",
        /\breč\b/i => "riječ",
        /\bistorija\b/i => "historija",
        /\btisuca\b/i => "hiljada",
        /\bstolece\b/i => "stoljeće",
        /\bstoleca\b/i => "stoljeća"
      }

      violations = []

      ekavica_patterns.each do |pattern, correct|
        if text.match?(pattern)
          match = text.match(pattern)
          violations << { found: match[0], should_be: correct }
        end
      end

      violations
    end

    def generic_title?(title)
      generic_patterns = [
        /^plan$/i,
        /^tour$/i,
        /^trip$/i,
        /^travel plan$/i,
        /^untitled$/i,
        /^new plan$/i,
        /^test/i
      ]

      generic_patterns.any? { |pattern| title.match?(pattern) }
    end

    def calculate_similarity(plan1, plan2)
      # Calculate title similarity
      title_sim = string_similarity(plan1.title.to_s.downcase, plan2.title.to_s.downcase)

      # Same profile + same city is a strong indicator of duplicate
      same_profile = plan1.preferences&.dig("tourist_profile") == plan2.preferences&.dig("tourist_profile")
      same_city = plan1.city_name == plan2.city_name
      profile_city_match = (same_profile && same_city) ? 0.4 : 0.0

      # Calculate experience overlap (optional - same experiences in plans might be OK)
      exp_ids_1 = plan1.plan_experiences.pluck(:experience_id).to_set
      exp_ids_2 = plan2.plan_experiences.pluck(:experience_id).to_set

      if exp_ids_1.empty? && exp_ids_2.empty?
        experience_sim = 0.0
      elsif exp_ids_1.empty? || exp_ids_2.empty?
        experience_sim = 0.0
      else
        intersection = (exp_ids_1 & exp_ids_2).size
        union = (exp_ids_1 | exp_ids_2).size
        experience_sim = intersection.to_f / union
      end

      # Weighted overall similarity
      # Profile+city match is heavily weighted because same profile for same city = duplicate
      overall = (title_sim * 0.3) + (profile_city_match) + (experience_sim * 0.2)

      {
        title: title_sim.round(3),
        same_profile: same_profile,
        same_city: same_city,
        experiences: experience_sim.round(3),
        overall: [overall, 1.0].min.round(3)
      }
    end

    def string_similarity(str1, str2)
      return 1.0 if str1 == str2
      return 0.0 if str1.empty? || str2.empty?

      # Use word-based Jaccard similarity for efficiency
      words1 = str1.split(/\s+/).to_set
      words2 = str2.split(/\s+/).to_set

      return 0.0 if words1.empty? && words2.empty?

      intersection = (words1 & words2).size
      union = (words1 | words2).size

      union.zero? ? 0.0 : (intersection.to_f / union)
    end

    def recommend_action(similarity, plan1, plan2)
      if similarity[:same_profile] && similarity[:same_city]
        :delete_duplicate_profile
      elsif similarity[:experiences] >= 0.8
        :merge_or_delete_duplicate
      elsif similarity[:title] >= 0.9
        :rename_for_clarity
      else
        :review_manually
      end
    end

    def determine_should_delete(plan, issues, score)
      # No experiences = nothing to show
      return true if plan.plan_experiences.count == 0

      # Score too low - too many critical issues to salvage
      return true if score <= DELETE_THRESHOLD_SCORE

      # Missing English title - no base content at all
      en_title = plan.translation_for(:title, :en).to_s
      return true if en_title.blank?

      # Plan has only placeholder/test content AND no real translations
      if generic_title?(plan.title.to_s)
        has_any_real_notes = REQUIRED_LOCALES.any? do |locale|
          notes = plan.translation_for(:notes, locale).to_s
          notes.present? && notes.length >= MIN_NOTES_LENGTH
        end
        return true unless has_any_real_notes
      end

      false
    end

    def explain_delete_reason(plan, issues, score)
      reasons = []

      reasons << "No experiences assigned" if plan.plan_experiences.count == 0
      reasons << "Quality score too low (#{score}/100)" if score <= DELETE_THRESHOLD_SCORE

      en_title = plan.translation_for(:title, :en).to_s
      reasons << "Missing English title" if en_title.blank?

      if generic_title?(plan.title.to_s)
        has_any_real_notes = REQUIRED_LOCALES.any? do |locale|
          notes = plan.translation_for(:notes, locale).to_s
          notes.present? && notes.length >= MIN_NOTES_LENGTH
        end
        reasons << "Generic/placeholder title with no substantial notes" unless has_any_real_notes
      end

      reasons.join("; ")
    end

    def calculate_quality_score(issues)
      # Lower score = worse quality
      base_score = 100

      issues.each do |issue|
        case issue[:severity]
        when :critical
          base_score -= 30
        when :high
          base_score -= 20
        when :medium
          base_score -= 10
        when :low
          base_score -= 5
        end
      end

      [base_score, 0].max
    end

    def group_issues_by_severity(results)
      all_issues = results.flat_map { |r| r[:issues] }

      {
        critical: all_issues.count { |i| i[:severity] == :critical },
        high: all_issues.count { |i| i[:severity] == :high },
        medium: all_issues.count { |i| i[:severity] == :medium },
        low: all_issues.count { |i| i[:severity] == :low }
      }
    end

    def group_issues_by_type(results)
      all_issues = results.flat_map { |r| r[:issues] }

      all_issues.group_by { |i| i[:type] }.transform_values(&:count)
    end
  end
end
