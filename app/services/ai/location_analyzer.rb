# frozen_string_literal: true

module Ai
  # Analyzes locations for description quality issues
  # Used by LocationCityFixJob to determine which locations need description regeneration
  class LocationAnalyzer
    include Concerns::ErrorReporting

    # Quality thresholds
    MIN_DESCRIPTION_LENGTH = 80  # Minimum chars for a valid description
    MIN_HISTORICAL_CONTEXT_LENGTH = 150  # Minimum chars for historical context

    # Required locales for complete translations
    REQUIRED_LOCALES = %w[en bs].freeze

    def initialize
      @issues_by_type = Hash.new { |h, k| h[k] = [] }
    end

    # Analyze a single location and return quality issues
    # @param location [Location] The location to analyze
    # @return [Hash] Analysis results with issues found
    def analyze(location)
      issues = []

      # Check description quality
      issues.concat(check_description_quality(location))

      # Check historical context quality
      issues.concat(check_historical_context_quality(location))

      # Check translation completeness
      issues.concat(check_translations(location))

      score = calculate_quality_score(issues)

      {
        location_id: location.id,
        name: location.name,
        city: location.city,
        issues: issues,
        score: score,
        needs_regeneration: issues.any? { |i| i[:severity] == :critical || i[:severity] == :high }
      }
    end

    # Check if a location needs description regeneration
    # @param location [Location] The location to check
    # @return [Boolean] true if regeneration is needed
    def needs_regeneration?(location)
      result = analyze(location)
      result[:needs_regeneration]
    end

    # Get the list of issues for a location
    # @param location [Location] The location to check
    # @return [Array<Hash>] List of issues
    def issues_for(location)
      result = analyze(location)
      result[:issues]
    end

    private

    def check_description_quality(location)
      issues = []

      # Check English description
      en_description = location.translation_for(:description, :en).to_s
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
      elsif placeholder_content?(en_description)
        issues << {
          type: :placeholder_description,
          severity: :critical,
          message: "English description appears to be placeholder/generic content",
          locale: "en"
        }
      end

      # Check Bosnian description for ijekavica violations
      bs_description = location.translation_for(:description, :bs).to_s
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

    def check_historical_context_quality(location)
      issues = []

      # Check English historical context
      en_context = location.translation_for(:historical_context, :en).to_s
      if en_context.blank?
        issues << {
          type: :missing_historical_context,
          severity: :medium,
          message: "Missing English historical context",
          locale: "en"
        }
      elsif en_context.length < MIN_HISTORICAL_CONTEXT_LENGTH
        issues << {
          type: :short_historical_context,
          severity: :medium,
          message: "English historical context too short (#{en_context.length} chars, min: #{MIN_HISTORICAL_CONTEXT_LENGTH})",
          locale: "en",
          current_length: en_context.length
        }
      end

      # Check Bosnian historical context for ijekavica violations
      bs_context = location.translation_for(:historical_context, :bs).to_s
      if bs_context.present?
        ekavica_violations = detect_ekavica(bs_context)
        if ekavica_violations.any?
          issues << {
            type: :ekavica_violation,
            severity: :high,
            message: "Bosnian historical context uses ekavica instead of ijekavica",
            violations: ekavica_violations.take(5),
            locale: "bs"
          }
        end
      end

      issues
    end

    def check_translations(location)
      issues = []

      REQUIRED_LOCALES.each do |locale|
        description = location.translation_for(:description, locale).to_s

        if description.blank?
          issues << {
            type: :missing_translation,
            severity: locale == "en" ? :critical : :high,
            message: "Missing #{locale.upcase} description translation",
            locale: locale
          }
        end
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
        /\bstoleca\b/i => "stoljeća",
        /\bceo\b/i => "cijeli",
        /\bcelokupan\b/i => "cjelokupan",
        /\bsecanje\b/i => "sjećanje",
        /\bpesnička\b/i => "pjesnička",
        /\bpesnik\b/i => "pjesnik"
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

    def placeholder_content?(text)
      placeholder_patterns = [
        /^description$/i,
        /^placeholder$/i,
        /^test$/i,
        /^lorem ipsum/i,
        /^todo/i,
        /^tbd$/i,
        /^n\/a$/i,
        /^coming soon$/i,
        /^to be added$/i,
        /^content goes here$/i
      ]

      placeholder_patterns.any? { |pattern| text.strip.match?(pattern) }
    end

    def calculate_quality_score(issues)
      # Higher score = better quality (100 = perfect)
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
  end
end
