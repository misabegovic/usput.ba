# frozen_string_literal: true

module Platform
  module DSL
    # Quality Standards - Defines production-ready content requirements
    #
    # Content MUST meet these standards before being considered complete.
    # Content Director agent uses these to validate work.
    #
    module QualityStandards
      # Minimum requirements for a production-ready location
      LOCATION_REQUIREMENTS = {
        required_fields: %i[name city lat lng],
        required_translations: {
          bs: %i[description],  # Bosnian description required
          en: %i[description]   # English description required
        },
        min_description_length: 100,  # Characters
        max_description_length: 2000
      }.freeze

      # Minimum requirements for a production-ready experience
      EXPERIENCE_REQUIREMENTS = {
        required_fields: %i[title estimated_duration],
        required_translations: {
          bs: %i[title description],
          en: %i[title description]
        },
        min_locations: 2,
        min_description_length: 150,
        max_description_length: 3000
      }.freeze

      class << self
        # Check if a location meets production quality standards
        # @param location [Location] The location to check
        # @return [Hash] { complete: Boolean, issues: Array<String> }
        def check_location(location)
          issues = []

          # Check required fields
          LOCATION_REQUIREMENTS[:required_fields].each do |field|
            value = location.send(field)
            if value.blank?
              issues << "Nedostaje obavezno polje: #{field}"
            end
          end

          # Check coordinates are valid
          if location.lat.present? && location.lng.present?
            unless Geo::BihBoundaryValidator.inside_bih?(location.lat, location.lng)
              issues << "Koordinate nisu unutar BiH"
            end
          end

          # Check translations
          LOCATION_REQUIREMENTS[:required_translations].each do |locale, fields|
            fields.each do |field|
              translation = location.translate(field, locale)
              if translation.blank?
                issues << "Nedostaje #{locale.upcase} prijevod za: #{field}"
              elsif translation.length < LOCATION_REQUIREMENTS[:min_description_length]
                issues << "#{locale.upcase} #{field} prekratak (#{translation.length} < #{LOCATION_REQUIREMENTS[:min_description_length]} karaktera)"
              end
            end
          end

          {
            complete: issues.empty?,
            issues: issues,
            location_id: location.id,
            location_name: location.name
          }
        end

        # Check if an experience meets production quality standards
        # @param experience [Experience] The experience to check
        # @return [Hash] { complete: Boolean, issues: Array<String> }
        def check_experience(experience)
          issues = []

          # Check required fields
          EXPERIENCE_REQUIREMENTS[:required_fields].each do |field|
            value = experience.send(field)
            if value.blank?
              issues << "Nedostaje obavezno polje: #{field}"
            end
          end

          # Check minimum locations
          locations_count = experience.locations.count
          if locations_count < EXPERIENCE_REQUIREMENTS[:min_locations]
            issues << "Premalo lokacija: #{locations_count} (minimum #{EXPERIENCE_REQUIREMENTS[:min_locations]})"
          end

          # Check translations
          EXPERIENCE_REQUIREMENTS[:required_translations].each do |locale, fields|
            fields.each do |field|
              translation = experience.translate(field, locale)
              if translation.blank?
                issues << "Nedostaje #{locale.upcase} prijevod za: #{field}"
              elsif field == :description && translation.length < EXPERIENCE_REQUIREMENTS[:min_description_length]
                issues << "#{locale.upcase} #{field} prekratak (#{translation.length} < #{EXPERIENCE_REQUIREMENTS[:min_description_length]} karaktera)"
              end
            end
          end

          # Check that all locations in experience are also complete
          experience.locations.each do |loc|
            loc_check = check_location(loc)
            unless loc_check[:complete]
              issues << "Lokacija '#{loc.name}' nije kompletna: #{loc_check[:issues].first}"
            end
          end

          {
            complete: issues.empty?,
            issues: issues,
            experience_id: experience.id,
            experience_title: experience.title,
            locations_count: locations_count
          }
        end

        # Audit all content and return summary
        # @return [Hash] Full audit report
        def full_audit
          location_issues = []
          experience_issues = []

          # Check all locations
          Location.find_each do |location|
            result = check_location(location)
            location_issues << result unless result[:complete]
          end

          # Check all experiences
          Experience.find_each do |experience|
            result = check_experience(experience)
            experience_issues << result unless result[:complete]
          end

          # Categorize issues
          locations_no_description = location_issues.select { |i| i[:issues].any? { |x| x.include?("prijevod") } }
          locations_no_coords = location_issues.select { |i| i[:issues].any? { |x| x.include?("lat") || x.include?("lng") } }
          experiences_no_locations = experience_issues.select { |i| i[:issues].any? { |x| x.include?("lokacija") } }
          experiences_no_description = experience_issues.select { |i| i[:issues].any? { |x| x.include?("prijevod") } }

          {
            summary: {
              total_locations: Location.count,
              complete_locations: Location.count - location_issues.size,
              incomplete_locations: location_issues.size,
              total_experiences: Experience.count,
              complete_experiences: Experience.count - experience_issues.size,
              incomplete_experiences: experience_issues.size
            },
            issues_breakdown: {
              locations_missing_translations: locations_no_description.size,
              locations_missing_coords: locations_no_coords.size,
              experiences_missing_locations: experiences_no_locations.size,
              experiences_missing_translations: experiences_no_description.size
            },
            incomplete_locations: location_issues.first(50),  # Limit for readability
            incomplete_experiences: experience_issues.first(50),
            production_ready: location_issues.empty? && experience_issues.empty?
          }
        end

        # Quick stats for dashboard
        # @return [Hash] Quality statistics
        def quality_stats
          total_locations = Location.count
          total_experiences = Experience.count

          # Count locations with BS description
          locs_with_bs_desc = Translation
            .where(translatable_type: "Location", field_name: "description", locale: "bs")
            .where.not(value: [ nil, "" ])
            .where("LENGTH(value) >= ?", LOCATION_REQUIREMENTS[:min_description_length])
            .distinct.count(:translatable_id)

          # Count locations with EN description
          locs_with_en_desc = Translation
            .where(translatable_type: "Location", field_name: "description", locale: "en")
            .where.not(value: [ nil, "" ])
            .distinct.count(:translatable_id)

          # Count experiences with BS description
          exps_with_bs_desc = Translation
            .where(translatable_type: "Experience", field_name: "description", locale: "bs")
            .where.not(value: [ nil, "" ])
            .where("LENGTH(value) >= ?", EXPERIENCE_REQUIREMENTS[:min_description_length])
            .distinct.count(:translatable_id)

          # Count experiences with EN description
          exps_with_en_desc = Translation
            .where(translatable_type: "Experience", field_name: "description", locale: "en")
            .where.not(value: [ nil, "" ])
            .distinct.count(:translatable_id)

          # Count experiences with minimum locations
          exps_with_locations = Experience
            .joins(:experience_locations)
            .group("experiences.id")
            .having("COUNT(experience_locations.id) >= ?", EXPERIENCE_REQUIREMENTS[:min_locations])
            .count.size

          {
            locations: {
              total: total_locations,
              with_bs_description: locs_with_bs_desc,
              with_en_description: locs_with_en_desc,
              complete_percent: total_locations > 0 ? ((locs_with_bs_desc.to_f / total_locations) * 100).round(1) : 0
            },
            experiences: {
              total: total_experiences,
              with_bs_description: exps_with_bs_desc,
              with_en_description: exps_with_en_desc,
              with_min_locations: exps_with_locations,
              complete_percent: total_experiences > 0 ? ((exps_with_bs_desc.to_f / total_experiences) * 100).round(1) : 0
            },
            overall_quality_score: calculate_quality_score(
              locs_with_bs_desc, total_locations,
              exps_with_bs_desc, exps_with_locations, total_experiences
            )
          }
        end

        private

        def calculate_quality_score(locs_bs, total_locs, exps_bs, exps_locs, total_exps)
          return 0 if total_locs == 0 && total_exps == 0

          loc_score = total_locs > 0 ? (locs_bs.to_f / total_locs) : 0
          exp_desc_score = total_exps > 0 ? (exps_bs.to_f / total_exps) : 0
          exp_locs_score = total_exps > 0 ? (exps_locs.to_f / total_exps) : 0

          # Weighted average: locations 40%, experience descriptions 30%, experience locations 30%
          ((loc_score * 0.4 + exp_desc_score * 0.3 + exp_locs_score * 0.3) * 100).round(1)
        end
      end
    end
  end
end
