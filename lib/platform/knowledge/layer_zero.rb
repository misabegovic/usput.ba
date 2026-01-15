# frozen_string_literal: true

module Platform
  module Knowledge
    # LayerZero - Cached statistike za brz pristup
    #
    # Pruža interface za pristup pre-computed statistikama
    # koje se osvježavaju periodično kroz StatisticsJob.
    #
    # Primjer:
    #   Platform::Knowledge::LayerZero.stats
    #   # => { locations: 523, experiences: 89, ... }
    #
    #   Platform::Knowledge::LayerZero.for_system_prompt
    #   # => Formatiran string za injection u system prompt
    #
    class LayerZero
      # Max starost statistika prije lazy refresh-a
      DEFAULT_MAX_AGE = 5.minutes

      class << self
        # Dohvati sve statistike za Layer 0
        def all(max_age: DEFAULT_MAX_AGE)
          PlatformStatistic.layer_zero(max_age: max_age)
        end

        # Dohvati content counts
        def stats(max_age: DEFAULT_MAX_AGE)
          PlatformStatistic.get("content_counts", max_age: max_age)
        end

        # Dohvati statistike po gradovima
        def by_city(max_age: DEFAULT_MAX_AGE)
          PlatformStatistic.get("by_city", max_age: max_age)
        end

        # Dohvati coverage metrrike
        def coverage(max_age: DEFAULT_MAX_AGE)
          PlatformStatistic.get("coverage", max_age: max_age)
        end

        # Dohvati health status
        def health(max_age: DEFAULT_MAX_AGE)
          PlatformStatistic.get("health", max_age: max_age)
        end

        # Forsiraj refresh svih statistika
        def refresh!
          PlatformStatistic.refresh_all
        end

        # Formatiraj Layer 0 za system prompt
        # Vraća kompaktan string (~500 tokena) sa ključnim informacijama
        def for_system_prompt(max_age: DEFAULT_MAX_AGE)
          data = all(max_age: max_age)
          return "" if data.blank?

          format_for_prompt(data)
        end

        # Provjeri da li su statistike fresh
        def fresh?(max_age = DEFAULT_MAX_AGE)
          stat = PlatformStatistic.find_by(key: "layer_zero")
          stat&.fresh?(max_age)
        end

        # Dohvati vrijeme zadnjeg računanja
        def last_computed_at
          PlatformStatistic.find_by(key: "layer_zero")&.computed_at
        end

        private

        def format_for_prompt(data)
          # Use with_indifferent_access to handle both symbol and string keys (JSON)
          data = data.with_indifferent_access
          stats = (data[:stats] || {}).with_indifferent_access
          by_city = data[:by_city] || {}
          coverage = (data[:coverage] || {}).with_indifferent_access
          top_rated = (data[:top_rated] || {}).with_indifferent_access
          recent = (data[:recent_changes] || {}).with_indifferent_access

          <<~PROMPT
            ## Trenutno stanje platforme (#{Time.current.strftime('%d.%m.%Y %H:%M')})

            ### Sadržaj
            - Lokacije: #{stats[:locations] || 0}
            - Iskustva: #{stats[:experiences] || 0}
            - Planovi: #{stats[:plans] || 0}
            - Audio ture: #{stats[:audio_tours] || 0}
            - Recenzije: #{stats[:reviews] || 0}
            - Korisnici: #{stats[:users] || 0} (kuratora: #{stats[:curators] || 0})

            ### Top gradovi
            #{format_cities(by_city)}

            ### Pokrivenost
            - Audio: #{coverage[:audio_coverage_percent] || 0}%
            - Opisi: #{coverage[:description_coverage_percent] || 0}%
            - AI generisano: #{coverage[:locations_ai_generated] || 0}
            - Human made: #{coverage[:locations_human_made] || 0}

            ### Zadnjih 7 dana
            - Nove lokacije: #{recent[:new_locations_7d] || 0}
            - Nove recenzije: #{recent[:new_reviews_7d] || 0}
            - Ažurirane lokacije: #{recent[:updated_locations_7d] || 0}

            ### Top ocijenjene lokacije
            #{format_top_rated(top_rated[:locations])}
          PROMPT
        end

        def format_cities(by_city)
          return "- Nema podataka" if by_city.blank?

          by_city.first(5).map { |city, count| "- #{city}: #{count}" }.join("\n")
        end

        def format_top_rated(locations)
          return "- Nema podataka" if locations.blank?

          locations.first(3).map do |loc|
            "- #{loc[:name]} (#{loc[:city]}) - #{loc[:rating]}⭐"
          end.join("\n")
        end
      end
    end
  end
end
