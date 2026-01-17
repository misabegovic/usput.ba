# frozen_string_literal: true

require_relative "../quality_standards"

module Platform
  module DSL
    module Executors
      # Quality executor - handles content quality auditing
      #
      # Commands:
      #   quality | audit     - Full quality audit
      #   quality | stats     - Quick quality statistics
      #   quality | check location { id: 123 } - Check specific location
      #   quality | check experience { id: 456 } - Check specific experience
      #   quality | incomplete locations - List incomplete locations
      #   quality | incomplete experiences - List incomplete experiences
      #
      module Quality
        class << self
          def execute_quality_query(ast)
            operation = ast[:operation] || :stats

            case operation.to_sym
            when :audit
              full_audit
            when :stats
              quality_stats
            when :check
              check_record(ast[:record_type], ast[:filters])
            when :incomplete
              list_incomplete(ast[:record_type], ast[:limit] || 20)
            else
              raise ExecutionError, "Nepoznata quality operacija: #{operation}"
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

          def check_record(record_type, filters)
            case record_type.to_s.downcase
            when "location", "locations"
              location = find_record(Location, filters)
              QualityStandards.check_location(location)
            when "experience", "experiences"
              experience = find_record(Experience, filters)
              QualityStandards.check_experience(experience)
            else
              raise ExecutionError, "Nepodržan tip za quality check: #{record_type}"
            end
          end

          def list_incomplete(record_type, limit)
            case record_type.to_s.downcase
            when "location", "locations"
              list_incomplete_locations(limit)
            when "experience", "experiences"
              list_incomplete_experiences(limit)
            else
              raise ExecutionError, "Nepodržan tip za incomplete listing: #{record_type}"
            end
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

          def find_record(model, filters)
            raise ExecutionError, "Potreban filter (npr. id)" if filters.nil? || filters.empty?

            if filters[:id]
              record = model.find_by(id: filters[:id])
              raise ExecutionError, "#{model.name} sa id=#{filters[:id]} nije pronađen" unless record
              record
            else
              raise ExecutionError, "Koristi id za quality check"
            end
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
