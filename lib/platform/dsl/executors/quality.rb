# frozen_string_literal: true

require_relative "../quality_standards"
require_relative "../content_validator"
require_relative "../validation_result"

module Platform
  module DSL
    module Executors
      # Quality executor - handles content quality auditing and validation
      #
      # Quality Commands:
      #   quality | audit        - Full quality audit
      #   quality | stats        - Quick quality statistics (default)
      #   quality | locations    - List incomplete locations
      #   quality | experiences  - List incomplete experiences
      #
      # Validation Commands:
      #   validate location { name: "X", city: "Y" }
      #   validate experience from locations [1, 2, 3]
      #   scan suspicious patterns
      #   find duplicates for location { name: "X" }
      #
      module Quality
        class << self
          # Execute validation commands
          def execute_validation(ast)
            case ast[:action]
            when :validate
              case ast[:validate_type]
              when :location
                validate_location(ast[:data])
              when :experience
                validate_experience(ast[:location_ids])
              else
                raise ExecutionError, "Nepoznat tip validacije: #{ast[:validate_type]}"
              end
            when :scan
              scan_suspicious_patterns
            when :find_duplicates
              find_duplicates(ast[:data])
            else
              raise ExecutionError, "Nepoznata validacijska akcija: #{ast[:action]}"
            end
          end

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

          # ===================
          # Validation methods
          # ===================

          # Validate a location before creation
          # @param data [Hash] Location data with :name and :city
          # @return [Hash] Validation result for DSL output
          def validate_location(data)
            name = data[:name]
            city = data[:city]

            raise ExecutionError, "Potreban je naziv lokacije (name)" if name.blank?
            raise ExecutionError, "Potreban je grad (city)" if city.blank?

            result = ContentValidator.validate_location(
              name: name,
              city: city,
              lat: data[:lat],
              lng: data[:lng]
            )

            {
              command: "validate location",
              input: { name: name, city: city },
              **result.to_dsl_response,
              formatted: result.to_cli_output
            }
          end

          # Validate an experience before creation
          # @param location_ids [Array<Integer>] Location IDs
          # @return [Hash] Validation result for DSL output
          def validate_experience(location_ids)
            raise ExecutionError, "Potrebni su ID-evi lokacija" if location_ids.blank?

            result = ContentValidator.validate_experience(location_ids: location_ids)

            {
              command: "validate experience",
              input: { location_ids: location_ids },
              **result.to_dsl_response,
              formatted: result.to_cli_output
            }
          end

          # Scan database for suspicious patterns (potential hallucinations)
          # @return [Hash] Scan results
          def scan_suspicious_patterns
            results = ContentValidator.scan_suspicious_patterns

            {
              command: "scan suspicious patterns",
              **results,
              formatted: format_scan_results(results)
            }
          end

          # Find potential duplicates for a location name
          # @param data [Hash] Data with :name and optional :city
          # @return [Hash] Duplicate search results
          def find_duplicates(data)
            name = data[:name]
            raise ExecutionError, "Potreban je naziv lokacije (name)" if name.blank?

            duplicates = ContentValidator.find_duplicates(name, data[:city])

            {
              command: "find duplicates",
              input: { name: name, city: data[:city] },
              found: duplicates.size,
              duplicates: duplicates,
              formatted: format_duplicates_results(name, duplicates)
            }
          end

          def format_scan_results(results)
            lines = ["=== SUSPICIOUS PATTERNS SCAN ===", ""]

            summary = results[:summary]
            lines << "SUMMARY:"
            lines << "  Total issues: #{summary[:total_issues]}"
            lines << "  High risk: #{summary[:high_risk_count]}"
            lines << "  Medium risk: #{summary[:medium_risk_count]}"
            lines << "  Wrong city: #{summary[:wrong_city_count]}"
            lines << "  Duplicates: #{summary[:duplicates_count]}"

            if results[:high_risk].any?
              lines << ""
              lines << "HIGH RISK (#{results[:high_risk].size}):"
              results[:high_risk].first(10).each do |issue|
                lines << "  ❌ ID #{issue[:id]}: #{issue[:name]} (#{issue[:city]})"
                lines << "     → #{issue[:issue]}"
              end
            end

            if results[:wrong_city].any?
              lines << ""
              lines << "WRONG CITY (#{results[:wrong_city].size}):"
              results[:wrong_city].first(10).each do |issue|
                lines << "  ⚠️  ID #{issue[:id]}: #{issue[:name]} (#{issue[:city]})"
                lines << "     → Expected: #{issue[:expected_city]}"
              end
            end

            if results[:duplicates].any?
              lines << ""
              lines << "DUPLICATES (#{results[:duplicates].size}):"
              results[:duplicates].first(5).each do |dup|
                lines << "  🔄 #{dup[:name]}"
                dup[:records].each do |r|
                  lines << "     ID #{r[:id]}: #{r[:name]} (#{r[:city]})"
                end
              end
            end

            lines.join("\n")
          end

          def format_duplicates_results(name, duplicates)
            lines = ["=== DUPLICATE SEARCH: #{name} ===", ""]

            if duplicates.empty?
              lines << "✅ No duplicates found"
            else
              lines << "⚠️  Found #{duplicates.size} potential duplicates:"
              lines << ""
              duplicates.each do |dup|
                match_label = case dup[:match_type]
                when :exact then "EXACT"
                when :similar then "SIMILAR"
                else "PARTIAL"
                end
                lines << "  [#{match_label}] ID #{dup[:id]}: #{dup[:name]} (#{dup[:city]})"
              end
            end

            lines.join("\n")
          end
        end
      end
    end
  end
end
