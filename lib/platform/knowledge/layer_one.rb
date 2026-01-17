# frozen_string_literal: true

module Platform
  module Knowledge
    # LayerOne - AI-generated summaries po dimenzijama
    #
    # Generira summary-je za gradove, kategorije i regije.
    # Koristi stratified sampling za efikasnost - ne čita sve rekorde.
    #
    # Primjer:
    #   Platform::Knowledge::LayerOne.generate_summary(:city, "Mostar")
    #   Platform::Knowledge::LayerOne.get_summary(:city, "Mostar")
    #   Platform::Knowledge::LayerOne.list_summaries(:city)
    #
    class LayerOne
      # Maksimalni broj uzoraka za AI analizu
      SAMPLE_SIZE = 10

      # Maksimalna starost summary-ja prije regeneracije
      DEFAULT_MAX_AGE = 1.hour

      class << self
        # Dohvati summary za dimenziju i vrijednost
        def get_summary(dimension, value, max_age: DEFAULT_MAX_AGE)
          summary = KnowledgeSummary.for_dimension_value(dimension, value)

          if summary&.fresh?(max_age)
            summary
          else
            # Lazy generate ako ne postoji ili je stale
            generate_summary(dimension, value)
          end
        end

        # Generiši summary za dimenziju i vrijednost
        def generate_summary(dimension, value)
          case dimension.to_s
          when "city"
            generate_city_summary(value)
          when "category"
            generate_category_summary(value)
          when "region"
            generate_region_summary(value)
          else
            raise ArgumentError, "Unknown dimension: #{dimension}"
          end
        end

        # Listaj sve summary-je za dimenziju
        def list_summaries(dimension)
          KnowledgeSummary.list_for_dimension(dimension)
        end

        # Dohvati summary-je sa issues
        def summaries_with_issues
          KnowledgeSummary.with_issues.recent
        end

        # Refresh sve summary-je za dimenziju
        def refresh_dimension(dimension)
          case dimension.to_s
          when "city"
            Location.distinct.pluck(:city).compact.each do |city|
              generate_city_summary(city)
            end
          when "category"
            # Generiši za svaku kategoriju
            LocationCategory.pluck(:key).each do |category|
              generate_category_summary(category)
            end
          end
        end

        # Dohvati dostupne dimenzije
        def available_dimensions
          KnowledgeSummary.available_dimensions
        end

        private

        # Helper: Get location IDs that have description translations
        def location_ids_with_description(scope = Location.all)
          Translation
            .where(translatable_type: "Location", field_name: "description")
            .where(translatable_id: scope.select(:id))
            .where.not(value: [nil, ""])
            .distinct
            .pluck(:translatable_id)
        end

        # Helper: Count locations with description in translations
        def count_with_description(scope)
          location_ids_with_description(scope).count
        end

        # Helper: Count locations without description in translations
        def count_without_description(scope)
          scope.count - count_with_description(scope)
        end

        # Generiši summary za grad
        def generate_city_summary(city)
          locations = Location.where(city: city)
          return nil if locations.empty?

          # Prikupi statistike
          stats = collect_city_stats(city, locations)

          # Uzmi uzorak za AI analizu
          sample = locations.order("RANDOM()").limit(SAMPLE_SIZE)
          sample_data = sample.map { |l| format_location_for_ai(l) }

          # Identifikuj issues
          issues = identify_city_issues(city, locations, stats)

          # Generiši summary sa AI (ili placeholder ako nema API)
          summary_text = generate_ai_summary(:city, city, stats, sample_data, issues)

          # Spremi
          save_summary(
            dimension: "city",
            dimension_value: city,
            summary: summary_text,
            stats: stats,
            issues: issues,
            patterns: detect_patterns(:city, stats),
            source_count: locations.count
          )
        end

        # Generiši summary za kategoriju
        def generate_category_summary(category)
          locations = Location.joins(:location_categories)
                              .where(location_categories: { key: category })
          return nil if locations.empty?

          stats = collect_category_stats(category, locations)
          sample = locations.order("RANDOM()").limit(SAMPLE_SIZE)
          sample_data = sample.map { |l| format_location_for_ai(l) }
          issues = identify_category_issues(category, locations, stats)
          summary_text = generate_ai_summary(:category, category, stats, sample_data, issues)

          save_summary(
            dimension: "category",
            dimension_value: category,
            summary: summary_text,
            stats: stats,
            issues: issues,
            patterns: detect_patterns(:category, stats),
            source_count: locations.count
          )
        end

        # Generiši summary za regiju (placeholder - zahtijeva region mapping)
        def generate_region_summary(region)
          # Za sada koristimo city kao proxy za region
          generate_city_summary(region)
        end

        # Prikupi statistike za grad
        def collect_city_stats(city, locations)
          total = locations.count
          with_desc = count_with_description(locations)
          {
            total_locations: total,
            with_audio: locations.with_audio.count,
            with_description: with_desc,
            ai_generated: locations.ai_generated.count,
            human_made: locations.human_made.count,
            avg_rating: locations.average(:average_rating)&.round(2) || 0,
            by_type: Location.joins(:location_categories)
                            .where(city: city)
                            .group("location_categories.key")
                            .count,
            audio_coverage: total > 0 ? (locations.with_audio.count * 100.0 / total).round(1) : 0,
            description_coverage: total > 0 ? (with_desc * 100.0 / total).round(1) : 0
          }
        end

        # Prikupi statistike za kategoriju
        def collect_category_stats(category, locations)
          total = locations.count
          with_desc = count_with_description(locations)
          {
            total_locations: total,
            with_audio: locations.with_audio.count,
            with_description: with_desc,
            by_city: locations.group(:city).count,
            avg_rating: locations.average(:average_rating)&.round(2) || 0,
            audio_coverage: total > 0 ? (locations.with_audio.count * 100.0 / total).round(1) : 0,
            description_coverage: total > 0 ? (with_desc * 100.0 / total).round(1) : 0
          }
        end

        # Identifikuj issues za grad
        def identify_city_issues(city, locations, stats)
          issues = []

          # Missing audio
          missing_audio = locations.count - locations.with_audio.count
          if missing_audio > 0
            issues << { type: "missing_audio", count: missing_audio }
          end

          # Missing descriptions (check translations table)
          missing_desc = count_without_description(locations)
          if missing_desc > 0
            issues << { type: "missing_description", count: missing_desc }
          end

          # Short descriptions (< 100 chars) - check translations table
          ids_with_desc = location_ids_with_description(locations)
          short_desc = Translation
            .where(translatable_type: "Location", field_name: "description")
            .where(translatable_id: ids_with_desc)
            .where("LENGTH(value) < ?", 100)
            .distinct
            .count(:translatable_id)
          if short_desc > 0
            issues << { type: "short_description", count: short_desc, threshold: 100 }
          end

          # Low audio coverage
          if stats[:audio_coverage] < 50
            issues << { type: "low_audio_coverage", percentage: stats[:audio_coverage] }
          end

          issues
        end

        # Identifikuj issues za kategoriju
        def identify_category_issues(category, locations, stats)
          issues = []

          missing_audio = locations.count - locations.with_audio.count
          issues << { type: "missing_audio", count: missing_audio } if missing_audio > 0

          # Missing descriptions (check translations table)
          missing_desc = count_without_description(locations)
          issues << { type: "missing_description", count: missing_desc } if missing_desc > 0

          issues
        end

        # Detektuj patterns
        def detect_patterns(dimension, stats)
          patterns = []

          case dimension.to_s
          when "city"
            if stats[:ai_generated].to_i > stats[:human_made].to_i
              patterns << "Većina sadržaja je AI generisana"
            end
            if stats[:audio_coverage].to_f > 70
              patterns << "Dobra audio pokrivenost (>70%)"
            elsif stats[:audio_coverage].to_f < 30
              patterns << "Slaba audio pokrivenost (<30%)"
            end
          when "category"
            if stats[:by_city]&.size == 1
              patterns << "Sve lokacije su u jednom gradu"
            elsif stats[:by_city]&.size.to_i > 5
              patterns << "Široka geografska distribucija"
            end
          end

          patterns
        end

        # Formatiraj lokaciju za AI
        def format_location_for_ai(location)
          {
            name: location.name,
            city: location.city,
            description: location.description&.truncate(200),
            has_audio: location.has_audio_tours?,
            rating: location.average_rating,
            categories: location.location_categories.pluck(:key)
          }
        end

        # Generiši AI summary
        def generate_ai_summary(dimension, value, stats, sample_data, issues)
          # Provjeri da li imamo RubyLLM konfigurisan
          unless RubyLLM.config.default_model.present?
            return generate_fallback_summary(dimension, value, stats, issues)
          end

          prompt = build_summary_prompt(dimension, value, stats, sample_data, issues)

          begin
            chat = RubyLLM.chat(model: RubyLLM.config.default_model)
            response = chat.ask(prompt)
            response.content
          rescue => e
            Rails.logger.warn "[LayerOne] AI summary generation failed: #{e.message}"
            generate_fallback_summary(dimension, value, stats, issues)
          end
        end

        # Build prompt za AI summary
        def build_summary_prompt(dimension, value, stats, sample_data, issues)
          <<~PROMPT
            Generiši kratak summary (3-5 rečenica) za #{dimension} "#{value}" na turističkoj platformi.

            Statistike:
            #{stats.to_json}

            Uzorak lokacija:
            #{sample_data.map { |s| "- #{s[:name]} (#{s[:city]}): #{s[:description]}" }.join("\n")}

            Identifikovani problemi:
            #{issues.map { |i| "- #{i[:type]}: #{i[:count] || i[:percentage]}" }.join("\n")}

            Napiši summary na bosanskom jeziku. Uključi:
            1. Kratak pregled stanja
            2. Glavne snage
            3. Glavne slabosti ili potrebe
            4. Jednu konkretnu preporuku

            Samo tekst, bez naslova ili formatiranja.
          PROMPT
        end

        # Fallback summary bez AI
        def generate_fallback_summary(dimension, value, stats, issues)
          issue_list = issues.map { |i| "#{i[:type]} (#{i[:count] || i[:percentage]})" }.join(", ")

          case dimension.to_s
          when "city"
            "#{value} ima #{stats[:total_locations]} lokacija. " \
            "Audio pokrivenost: #{stats[:audio_coverage]}%. " \
            "Prosječna ocjena: #{stats[:avg_rating]}. " \
            "#{issues.any? ? "Problemi: #{issue_list}." : "Nema kritičnih problema."}"
          when "category"
            "Kategorija '#{value}' sadrži #{stats[:total_locations]} lokacija u #{stats[:by_city]&.size || 0} gradova. " \
            "Audio pokrivenost: #{stats[:audio_coverage]}%. " \
            "#{issues.any? ? "Problemi: #{issue_list}." : "Nema kritičnih problema."}"
          else
            "Summary za #{dimension} #{value}: #{stats[:total_locations]} stavki."
          end
        end

        # Spremi summary
        def save_summary(dimension:, dimension_value:, summary:, stats:, issues:, patterns:, source_count:)
          record = KnowledgeSummary.find_or_initialize_by(
            dimension: dimension,
            dimension_value: dimension_value
          )

          record.update!(
            summary: summary,
            stats: stats,
            issues: issues,
            patterns: patterns,
            source_count: source_count,
            generated_at: Time.current
          )

          record
        end
      end
    end
  end
end
