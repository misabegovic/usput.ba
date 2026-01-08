# frozen_string_literal: true

module Ai
  # Analyzes experiences for quality issues and similarity to other experiences
  # Used by RebuildExperiencesJob to determine which experiences need regeneration
  class ExperienceAnalyzer
    include Concerns::ErrorReporting

    # Quality thresholds
    MIN_DESCRIPTION_LENGTH = 100
    MIN_TITLE_LENGTH = 5
    MIN_LOCATIONS_COUNT = 1
    SIMILARITY_THRESHOLD = 0.7 # 70% overlap considered too similar

    # Score below which an experience should be deleted rather than regenerated
    DELETE_THRESHOLD_SCORE = 20

    # Required locales for complete translations
    REQUIRED_LOCALES = %w[en bs].freeze

    # Location types that shouldn't be in experiences
    EXCLUDED_LOCATION_TYPES = %i[accommodation].freeze

    # Category keys that indicate accommodation (shouldn't be in experiences)
    ACCOMMODATION_CATEGORY_KEYS = %w[
      hotel hostel motel guest_house apartment lodging accommodation
      dom_penzionera retirement_home nursing_home
    ].freeze

    def initialize
      @issues_by_type = Hash.new { |h, k| h[k] = [] }
    end

    # Analyze a single experience and return quality issues
    # @param experience [Experience] The experience to analyze
    # @return [Hash] Analysis results with issues found
    def analyze(experience)
      issues = []

      # Check description quality
      issues.concat(check_description_quality(experience))

      # Check title quality
      issues.concat(check_title_quality(experience))

      # Check translation completeness
      issues.concat(check_translations(experience))

      # Check location count
      issues.concat(check_locations(experience))

      # Check for accommodation locations (shouldn't be in experiences)
      issues.concat(check_accommodation_locations(experience))

      # Check category assignment
      issues.concat(check_category(experience))

      # Check estimated duration
      issues.concat(check_duration(experience))

      score = calculate_quality_score(issues)
      should_delete = determine_should_delete(experience, issues, score)

      {
        experience_id: experience.id,
        title: experience.title,
        city: experience.city,
        issues: issues,
        score: score,
        needs_rebuild: !should_delete && issues.any? { |i| i[:severity] == :critical || i[:severity] == :high },
        should_delete: should_delete,
        delete_reason: should_delete ? explain_delete_reason(experience, issues, score) : nil
      }
    end

    # Analyze all experiences and find quality issues
    # @return [Array<Hash>] Array of analysis results
    def analyze_all
      results = []

      Experience.includes(:locations, :experience_category, :translations).find_each do |experience|
        result = analyze(experience)
        results << result if result[:issues].any?
      end

      results.sort_by { |r| r[:score] }
    end

    # Find experiences that are too similar to each other
    # @return [Array<Hash>] Array of similarity groups
    def find_similar_experiences
      similar_groups = []
      experiences = Experience.includes(:locations, :translations).to_a

      experiences.each_with_index do |exp1, i|
        experiences[(i + 1)..].each do |exp2|
          similarity = calculate_similarity(exp1, exp2)

          if similarity[:overall] >= SIMILARITY_THRESHOLD
            similar_groups << {
              experience_1: { id: exp1.id, title: exp1.title, city: exp1.city },
              experience_2: { id: exp2.id, title: exp2.title, city: exp2.city },
              similarity: similarity,
              recommendation: recommend_action(similarity)
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
      similar_experiences = []

      Experience.includes(:locations, :experience_category, :translations).find_each do |experience|
        result = analyze(experience)
        all_results << result
      end

      similar_experiences = find_similar_experiences

      experiences_to_delete = all_results.select { |r| r[:should_delete] }
      experiences_to_rebuild = all_results.select { |r| r[:needs_rebuild] && !r[:should_delete] }

      {
        total_experiences: all_results.count,
        experiences_with_issues: all_results.count { |r| r[:issues].any? },
        experiences_needing_rebuild: experiences_to_rebuild.count,
        experiences_to_delete: experiences_to_delete.count,
        similar_experience_pairs: similar_experiences.count,
        issues_by_severity: group_issues_by_severity(all_results),
        issues_by_type: group_issues_by_type(all_results),
        worst_experiences: experiences_to_rebuild.take(20),
        deletable_experiences: experiences_to_delete.take(20),
        similar_experiences: similar_experiences.take(10)
      }
    end

    private

    def check_description_quality(experience)
      issues = []

      # Check English description
      en_description = experience.translation_for(:description, :en).to_s
      if en_description.blank?
        issues << {
          type: :missing_description,
          severity: :critical,
          message: "Missing English description",
          locale: "en"
        }
      elsif en_description.length < MIN_DESCRIPTION_LENGTH
        issues << {
          type: :short_description,
          severity: :high,
          message: "English description too short (#{en_description.length} chars, min: #{MIN_DESCRIPTION_LENGTH})",
          locale: "en",
          current_length: en_description.length
        }
      end

      # Check Bosnian description for ijekavica violations
      bs_description = experience.translation_for(:description, :bs).to_s
      if bs_description.present?
        ekavica_violations = detect_ekavica(bs_description)
        if ekavica_violations.any?
          issues << {
            type: :ekavica_violation,
            severity: :high,
            message: "Bosnian description uses ekavica instead of ijekavica",
            violations: ekavica_violations.take(5),
            locale: "bs"
          }
        end
      end

      issues
    end

    def check_title_quality(experience)
      issues = []

      title = experience.title.to_s
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
      bs_title = experience.translation_for(:title, :bs).to_s
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

    def check_translations(experience)
      issues = []

      REQUIRED_LOCALES.each do |locale|
        title = experience.translation_for(:title, locale).to_s
        description = experience.translation_for(:description, locale).to_s

        if title.blank? && description.blank?
          issues << {
            type: :missing_translation,
            severity: locale == "en" ? :critical : :medium,
            message: "Missing #{locale.upcase} translation (title and description)",
            locale: locale
          }
        elsif title.blank?
          issues << {
            type: :missing_translation,
            severity: locale == "en" ? :critical : :medium,
            message: "Missing #{locale.upcase} title translation",
            locale: locale
          }
        elsif description.blank?
          issues << {
            type: :missing_translation,
            severity: locale == "en" ? :high : :medium,
            message: "Missing #{locale.upcase} description translation",
            locale: locale
          }
        end
      end

      issues
    end

    def check_locations(experience)
      issues = []

      location_count = experience.locations.count

      if location_count == 0
        issues << {
          type: :no_locations,
          severity: :critical,
          message: "Experience has no locations"
        }
      elsif location_count < MIN_LOCATIONS_COUNT
        issues << {
          type: :few_locations,
          severity: :medium,
          message: "Experience has only #{location_count} location(s), recommended: #{MIN_LOCATIONS_COUNT}+",
          current_count: location_count
        }
      end

      issues
    end

    # Check if experience has too many accommodation locations
    # Some accommodation is OK (if it has special value), but too much indicates poor curation
    def check_accommodation_locations(experience)
      issues = []

      total_locations = experience.locations.count
      return issues if total_locations == 0

      accommodation_locations = experience.locations.select do |location|
        accommodation_location?(location)
      end

      accommodation_count = accommodation_locations.count
      accommodation_ratio = accommodation_count.to_f / total_locations

      # Flag if more than 50% of locations are accommodation - that's too much
      if accommodation_ratio > 0.5 && accommodation_count > 1
        issues << {
          type: :too_many_accommodation_locations,
          severity: :high,
          message: "Experience has too many accommodation locations (#{accommodation_count}/#{total_locations} = #{(accommodation_ratio * 100).round}%)",
          location_ids: accommodation_locations.map(&:id),
          location_names: accommodation_locations.map(&:name),
          accommodation_ratio: accommodation_ratio.round(2)
        }
      # Also flag if the only location is accommodation
      elsif total_locations == 1 && accommodation_count == 1
        issues << {
          type: :only_accommodation_location,
          severity: :medium,
          message: "Experience only contains accommodation location '#{accommodation_locations.first&.name}'",
          location_ids: accommodation_locations.map(&:id),
          location_names: accommodation_locations.map(&:name)
        }
      end

      issues
    end

    # Check if a location is an accommodation type
    def accommodation_location?(location)
      # Check location_type enum
      return true if location.location_type.present? && EXCLUDED_LOCATION_TYPES.include?(location.location_type.to_sym)

      # Check location categories
      if location.respond_to?(:location_categories) && location.location_categories.loaded?
        category_keys = location.location_categories.map { |c| c.key.to_s.downcase }
        return true if category_keys.any? { |key| ACCOMMODATION_CATEGORY_KEYS.any? { |exc| key.include?(exc) } }
      elsif location.respond_to?(:location_categories)
        category_keys = location.location_categories.pluck(:key).map(&:to_s).map(&:downcase)
        return true if category_keys.any? { |key| ACCOMMODATION_CATEGORY_KEYS.any? { |exc| key.include?(exc) } }
      end

      # Check tags for accommodation-related keywords
      if location.tags.present?
        tags_downcase = location.tags.map(&:to_s).map(&:downcase)
        accommodation_tags = %w[hotel hostel motel lodging accommodation smještaj smjestaj]
        return true if (tags_downcase & accommodation_tags).any?
      end

      false
    end

    def check_category(experience)
      issues = []

      if experience.experience_category.nil?
        issues << {
          type: :missing_category,
          severity: :low,
          message: "Experience has no category assigned"
        }
      end

      issues
    end

    def check_duration(experience)
      issues = []

      if experience.estimated_duration.nil?
        issues << {
          type: :missing_duration,
          severity: :low,
          message: "Experience has no estimated duration"
        }
      elsif experience.estimated_duration <= 0
        issues << {
          type: :invalid_duration,
          severity: :medium,
          message: "Experience has invalid duration: #{experience.estimated_duration}"
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
        /\bcrno\b/i => "crno", # same in both
        /\bpevati\b/i => "pjevati",
        /\bsvet\b/i => "svijet",
        /\bčovek\b/i => "čovjek",
        /\bdevojka\b/i => "djevojka",
        /\bdeca\b/i => "djeca",
        /\breč\b/i => "riječ",
        /\bsreća\b/i => "sreća", # same in both
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
        /^experience$/i,
        /^tour$/i,
        /^city tour$/i,
        /^walking tour$/i,
        /^untitled$/i,
        /^new experience$/i,
        /^test/i
      ]

      generic_patterns.any? { |pattern| title.match?(pattern) }
    end

    def calculate_similarity(exp1, exp2)
      # Calculate title similarity using Levenshtein-like comparison
      title_sim = string_similarity(exp1.title.to_s.downcase, exp2.title.to_s.downcase)

      # Calculate location overlap
      loc_ids_1 = exp1.locations.pluck(:id).to_set
      loc_ids_2 = exp2.locations.pluck(:id).to_set

      if loc_ids_1.empty? && loc_ids_2.empty?
        location_sim = 0.0
      elsif loc_ids_1.empty? || loc_ids_2.empty?
        location_sim = 0.0
      else
        intersection = (loc_ids_1 & loc_ids_2).size
        union = (loc_ids_1 | loc_ids_2).size
        location_sim = intersection.to_f / union
      end

      # Calculate description similarity (sample-based for performance)
      desc_sim = string_similarity(
        exp1.description.to_s.downcase.truncate(500),
        exp2.description.to_s.downcase.truncate(500)
      )

      # Same city bonus
      same_city = exp1.city == exp2.city ? 0.1 : 0.0

      # Weighted overall similarity
      overall = (title_sim * 0.3) + (location_sim * 0.5) + (desc_sim * 0.1) + same_city

      {
        title: title_sim.round(3),
        locations: location_sim.round(3),
        description: desc_sim.round(3),
        same_city: exp1.city == exp2.city,
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

    def recommend_action(similarity)
      if similarity[:locations] >= 0.8
        :merge_or_delete_duplicate
      elsif similarity[:locations] >= 0.6
        :review_for_differentiation
      elsif similarity[:title] >= 0.9
        :rename_for_clarity
      else
        :review_manually
      end
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

    # Determine if an experience should be deleted rather than regenerated
    # This is the case when the experience is fundamentally broken and
    # regeneration would not make sense
    def determine_should_delete(experience, issues, score)
      # No locations = nothing to build an experience from
      return true if experience.locations.count == 0

      # Score too low - too many critical issues to salvage
      return true if score <= DELETE_THRESHOLD_SCORE

      # Missing both English title AND description - no base content at all
      en_title = experience.translation_for(:title, :en).to_s
      en_desc = experience.translation_for(:description, :en).to_s
      return true if en_title.blank? && en_desc.blank?

      # All locations have been deleted (orphaned experience)
      return true if experience.experience_locations.count == 0

      # Experience has only placeholder/test content AND no real translations
      if generic_title?(experience.title.to_s)
        has_any_real_content = REQUIRED_LOCALES.any? do |locale|
          desc = experience.translation_for(:description, locale).to_s
          desc.present? && desc.length >= MIN_DESCRIPTION_LENGTH
        end
        return true unless has_any_real_content
      end

      false
    end

    # Explain why an experience should be deleted
    def explain_delete_reason(experience, issues, score)
      reasons = []

      reasons << "No locations attached" if experience.locations.count == 0
      reasons << "Quality score too low (#{score}/100)" if score <= DELETE_THRESHOLD_SCORE

      en_title = experience.translation_for(:title, :en).to_s
      en_desc = experience.translation_for(:description, :en).to_s
      reasons << "Missing all English content" if en_title.blank? && en_desc.blank?

      reasons << "Orphaned experience (no location associations)" if experience.experience_locations.count == 0

      if generic_title?(experience.title.to_s)
        has_any_real_content = REQUIRED_LOCALES.any? do |locale|
          desc = experience.translation_for(:description, locale).to_s
          desc.present? && desc.length >= MIN_DESCRIPTION_LENGTH
        end
        reasons << "Generic/placeholder title with no substantial content" unless has_any_real_content
      end

      reasons.join("; ")
    end
  end
end
