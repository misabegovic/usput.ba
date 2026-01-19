# frozen_string_literal: true

require_relative "../quality_standards"

module Platform
  module DSL
    module Executors
      # Quality executor - handles content quality auditing
      #
      # Commands:
      #   quality | audit        - Full quality audit
      #   quality | stats        - Quick quality statistics (default)
      #   quality | locations    - List incomplete locations
      #   quality | experiences  - List incomplete experiences
      #
      module Quality
        class << self
          def execute_quality_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :audit
              full_audit
            when :stats
              quality_stats
            when :locations
              list_incomplete_locations(filters[:limit] || 20)
            when :experiences
              list_incomplete_experiences(filters[:limit] || 20)
            when nil
              # Default to stats if no operation specified
              quality_stats
            else
              raise ExecutionError, "Nepoznata quality operacija: #{operation&.dig(:name)}"
            end
          end

          private

          def full_audit
            QualityStandards.full_audit
          end

          def quality_stats
            stats = QualityStandards.quality_stats

            # Add formatted output
            {
              **stats,
              formatted: format_quality_stats(stats)
            }
          end

          def list_incomplete_locations(limit)
            incomplete = []

            # Find locations without BS description
            ids_with_bs_desc = Translation
              .where(translatable_type: "Location", field_name: "description", locale: "bs")
              .where.not(value: [nil, ""])
              .where("LENGTH(value) >= ?", QualityStandards::LOCATION_REQUIREMENTS[:min_description_length])
              .pluck(:translatable_id)

            Location.where.not(id: ids_with_bs_desc).limit(limit).each do |loc|
              result = QualityStandards.check_location(loc)
              incomplete << result unless result[:complete]
            end

            {
              type: "incomplete_locations",
              count: Location.where.not(id: ids_with_bs_desc).count,
              showing: incomplete.size,
              items: incomplete
            }
          end

          def list_incomplete_experiences(limit)
            incomplete = []

            # Find experiences without BS description or without enough locations
            ids_with_bs_desc = Translation
              .where(translatable_type: "Experience", field_name: "description", locale: "bs")
              .where.not(value: [nil, ""])
              .where("LENGTH(value) >= ?", QualityStandards::EXPERIENCE_REQUIREMENTS[:min_description_length])
              .pluck(:translatable_id)

            Experience.where.not(id: ids_with_bs_desc).limit(limit).each do |exp|
              result = QualityStandards.check_experience(exp)
              incomplete << result unless result[:complete]
            end

            {
              type: "incomplete_experiences",
              count: Experience.where.not(id: ids_with_bs_desc).count,
              showing: incomplete.size,
              items: incomplete
            }
          end

          def format_quality_stats(stats)
            loc = stats[:locations]
            exp = stats[:experiences]

            <<~REPORT
              === QUALITY REPORT ===

              LOKACIJE (#{loc[:total]} ukupno):
                ✓ BS opis: #{loc[:with_bs_description]} (#{loc[:complete_percent]}%)
                ✓ EN opis: #{loc[:with_en_description]}

              ISKUSTVA (#{exp[:total]} ukupno):
                ✓ BS opis: #{exp[:with_bs_description]} (#{exp[:complete_percent]}%)
                ✓ EN opis: #{exp[:with_en_description]}
                ✓ Sa lokacijama: #{exp[:with_min_locations]}

              UKUPNI QUALITY SCORE: #{stats[:overall_quality_score]}%

              Cilj: 100% (sve lokacije i iskustva kompletna)
            REPORT
          end
        end
      end
    end
  end
end
