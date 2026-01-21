# frozen_string_literal: true

require_relative "validation_result"

module Platform
  module DSL
    # ContentValidator - Validira sadržaj prije kreiranja
    #
    # Provjerava:
    # - Sumnjive obrasce u nazivima (halucinacije)
    # - Duplikate
    # - Geoapify postojanje lokacije
    # - BiH granice
    # - Pogrešan grad za poznate lokacije
    #
    # Primjer:
    #   result = ContentValidator.validate_location(name: "Stari most", city: "Mostar")
    #   result.valid? # => true
    #
    class ContentValidator
      # Sumnjivi obrasci koji često ukazuju na halucinacije
      SUSPICIOUS_PATTERNS = {
        high_risk: [
          { pattern: /rimske?\s+terme/i, message: "Generički naziv 'rimske terme' - vjerovatno ne postoji" },
          { pattern: /thermal\s+waters?/i, message: "Naziv 'thermal waters' - provjeri da nije iz druge države" },
          { pattern: /roman\s+baths?/i, message: "Generički naziv 'roman baths' - provjeri postojanje" },
          { pattern: /\[?grad\]?\s+(cultural|visitor)\s+center/i, message: "Generički naziv centra - provjeri tačan naziv" },
          { pattern: /spa\s+experience/i, message: "Generički spa naziv - provjeri da postoji" },
          { pattern: /wellness\s+retreat/i, message: "Generički wellness naziv - provjeri da postoji" }
        ],
        medium_risk: [
          { pattern: /\bspa\b(?!\s+hotel)/i, message: "Naziv sadrži 'spa' - verificiraj na booking.com" },
          { pattern: /wellness/i, message: "Naziv sadrži 'wellness' - verificiraj postojanje" },
          { pattern: /terme(?!\s+ilid)/i, message: "Naziv sadrži 'terme' - provjeri tačan naziv" },
          { pattern: /resort/i, message: "Naziv sadrži 'resort' - verificiraj na booking.com" },
          { pattern: /hotel\s+\w+$/i, message: "Hotel - verificiraj da postoji" }
        ]
      }.freeze

      # Poznate lokacije sa očekivanim gradovima
      KNOWN_LOCATIONS = {
        /kravic/i => { expected_city: "Ljubuški", message: "Kravica vodopad je u Ljubuškom, ne u %{city}" },
        /guber/i => { expected_city: "Srebrenica", message: "Guber izvori su u Srebrenici, ne u %{city}" },
        /stari\s+most/i => { expected_city: "Mostar", message: "Stari most je u Mostaru, ne u %{city}" },
        /blagaj/i => { expected_city: "Blagaj", message: "Blagaj je zaseban grad, ne dio %{city}" },
        /trebinje/i => { expected_city: "Trebinje", message: "Trebinje je zaseban grad" },
        /vrelo\s+bosne/i => { expected_city: "Ilidža", message: "Vrelo Bosne je u Ilidži" },
        /tunel\s+spasa/i => { expected_city: "Sarajevo", alternatives: ["Ilidža"], message: "Tunel spasa je u Sarajevu/Ilidži" }
      }.freeze

      # Gradovi koji postoje u drugim državama
      AMBIGUOUS_CITIES = {
        "Tuzla" => { other_countries: ["Turkey"], warning: "Tuzla postoji i u Turskoj - provjeri da je BiH lokacija" },
        "Mostar" => { other_countries: ["Czech Republic"], warning: "Postoje mjesta sa sličnim imenom - provjeri koordinate" }
      }.freeze

      class << self
        # Validira lokaciju prije kreiranja
        #
        # @param name [String] Naziv lokacije
        # @param city [String] Grad
        # @param lat [Float, nil] Latitude (opcionalno)
        # @param lng [Float, nil] Longitude (opcionalno)
        # @return [ValidationResult]
        def validate_location(name:, city:, lat: nil, lng: nil)
          result = ValidationResult.new

          # 1. Provjeri sumnjive obrasce u nazivu
          result.merge!(check_suspicious_patterns(name))

          # 2. Provjeri poznate lokacije sa očekivanim gradovima
          result.merge!(check_known_location_city(name, city))

          # 3. Provjeri ambiguozne gradove
          result.merge!(check_ambiguous_city(city))

          # 4. Provjeri duplikate u bazi
          result.merge!(check_duplicates(name, city))

          # 5. Ako nema koordinata, provjeri Geoapify
          if lat.nil? || lng.nil?
            result.merge!(check_geoapify(name, city))
          else
            result.coordinates = { lat: lat, lng: lng }
            # Provjeri BiH granice
            result.merge!(check_bih_boundaries(lat, lng))
          end

          # Dodaj sugestije na osnovu statusa
          add_suggestions(result, name, city)

          result
        end

        # Validira iskustvo prije kreiranja
        #
        # @param location_ids [Array<Integer>] ID-evi lokacija
        # @return [ValidationResult]
        def validate_experience(location_ids:)
          result = ValidationResult.new

          # 1. Provjeri da imamo dovoljno lokacija
          if location_ids.size < 2
            result.add_error("Potrebne su najmanje 2 lokacije za iskustvo", code: :insufficient_locations)
            return result
          end

          # 2. Provjeri da lokacije postoje
          locations = Location.where(id: location_ids).to_a
          missing = location_ids - locations.map(&:id)
          if missing.any?
            result.add_error("Lokacije nisu pronađene: #{missing.join(', ')}", code: :locations_not_found)
          end

          # 3. Provjeri da lokacije imaju opise
          incomplete = locations.select { |l| l.description.blank? || l.description.length < 50 }
          if incomplete.any?
            result.add_warning(
              "Lokacije bez kompletnog opisa: #{incomplete.map { |l| "#{l.id} (#{l.name})" }.join(', ')}",
              code: :incomplete_locations
            )
          end

          # 4. Provjeri geografsku koherentnost (da nisu predaleko)
          result.merge!(check_geographic_coherence(locations))

          result
        end

        # Skenira bazu za sumnjive obrasce
        #
        # @return [Hash] Rezultati skeniranja
        def scan_suspicious_patterns
          results = { high_risk: [], medium_risk: [], wrong_city: [], duplicates: [] }

          Location.find_each do |loc|
            # High risk patterns
            SUSPICIOUS_PATTERNS[:high_risk].each do |check|
              if loc.name =~ check[:pattern]
                results[:high_risk] << {
                  id: loc.id, name: loc.name, city: loc.city,
                  issue: check[:message], risk: :high
                }
              end
            end

            # Medium risk patterns
            SUSPICIOUS_PATTERNS[:medium_risk].each do |check|
              if loc.name =~ check[:pattern]
                results[:medium_risk] << {
                  id: loc.id, name: loc.name, city: loc.city,
                  issue: check[:message], risk: :medium
                }
              end
            end

            # Known locations in wrong city
            KNOWN_LOCATIONS.each do |pattern, info|
              if loc.name =~ pattern
                expected = info[:expected_city]
                alternatives = info[:alternatives] || []
                unless loc.city == expected || alternatives.include?(loc.city)
                  results[:wrong_city] << {
                    id: loc.id, name: loc.name, city: loc.city,
                    expected_city: expected, issue: info[:message] % { city: loc.city }
                  }
                end
              end
            end
          end

          # Find duplicates
          results[:duplicates] = find_all_duplicates

          results[:summary] = {
            total_issues: results[:high_risk].size + results[:medium_risk].size + results[:wrong_city].size + results[:duplicates].size,
            high_risk_count: results[:high_risk].size,
            medium_risk_count: results[:medium_risk].size,
            wrong_city_count: results[:wrong_city].size,
            duplicates_count: results[:duplicates].size
          }

          results
        end

        # Pronalazi duplikate za dati naziv
        #
        # @param name [String] Naziv lokacije
        # @param city [String, nil] Grad (opcionalno)
        # @return [Array<Hash>] Lista potencijalnih duplikata
        def find_duplicates(name, city = nil)
          # Normaliziraj naziv za pretragu
          normalized = normalize_name(name)

          duplicates = []

          # Exact match (case insensitive)
          exact = Location.where("LOWER(name) = ?", name.downcase)
          exact = exact.where(city: city) if city
          exact_ids = exact.pluck(:id)
          duplicates.concat(exact.map { |l| format_duplicate(l, :exact) })

          # Use LIKE for partial matches (safer than pg_trgm which may not be available)
          begin
            like_matches = Location.where("LOWER(name) LIKE ?", "%#{normalized}%")
              .where.not(id: exact_ids)
              .limit(10)
            duplicates.concat(like_matches.map { |l| format_duplicate(l, :partial) })
          rescue StandardError => e
            Rails.logger.warn "[ContentValidator] Duplicate search failed: #{e.message}"
          end

          duplicates.uniq { |d| d[:id] }
        end

        private

        def check_suspicious_patterns(name)
          result = ValidationResult.new

          SUSPICIOUS_PATTERNS[:high_risk].each do |check|
            if name =~ check[:pattern]
              result.add_warning(check[:message], code: :suspicious_pattern_high)
            end
          end

          SUSPICIOUS_PATTERNS[:medium_risk].each do |check|
            if name =~ check[:pattern]
              result.add_warning(check[:message], code: :suspicious_pattern_medium)
            end
          end

          result
        end

        def check_known_location_city(name, city)
          result = ValidationResult.new

          KNOWN_LOCATIONS.each do |pattern, info|
            next unless name =~ pattern

            expected = info[:expected_city]
            alternatives = info[:alternatives] || []

            unless city == expected || alternatives.include?(city)
              result.add_warning(
                info[:message] % { city: city },
                code: :wrong_city,
                details: { expected: expected, got: city }
              )
            end
          end

          result
        end

        def check_ambiguous_city(city)
          result = ValidationResult.new

          if info = AMBIGUOUS_CITIES[city]
            result.add_warning(info[:warning], code: :ambiguous_city)
          end

          result
        end

        def check_duplicates(name, city)
          result = ValidationResult.new

          existing = find_duplicates(name, city)
          if existing.any?
            exact = existing.select { |d| d[:match_type] == :exact }
            if exact.any?
              result.add_error(
                "Lokacija sa istim imenom već postoji: #{exact.map { |d| "ID #{d[:id]} (#{d[:city]})" }.join(', ')}",
                code: :duplicate_exact,
                details: exact
              )
              result.existing_record = exact.first
            else
              result.add_warning(
                "Pronađene slične lokacije: #{existing.map { |d| "#{d[:name]} (#{d[:city]})" }.join(', ')}",
                code: :duplicate_similar,
                details: existing
              )
            end
          end

          result
        end

        def check_geoapify(name, city)
          result = ValidationResult.new

          begin
            service = GeoapifyService.new
            query = "#{name}, #{city}, Bosnia and Herzegovina"
            results = service.text_search(query: query)

            if results.empty?
              result.add_warning(
                "Geoapify nije pronašao lokaciju '#{name}' u '#{city}'",
                code: :geoapify_not_found
              )
              result.add_suggestion("Provjeri da lokacija zaista postoji u BiH")
              return result
            end

            # Filter to BiH only
            bih_results = results.select do |r|
              r[:lat].present? && r[:lng].present? &&
                Geo::BihBoundaryValidator.inside_bih?(r[:lat], r[:lng])
            end

            if bih_results.empty?
              result.add_error(
                "Geoapify rezultati nisu unutar granica BiH",
                code: :outside_bih
              )
              result.add_suggestion("Ova lokacija možda nije u Bosni i Hercegovini")
              return result
            end

            # Provjeri da li je rezultat u očekivanom gradu
            best = bih_results.first
            if city.present? && best[:address].present?
              address_lower = best[:address].to_s.downcase
              city_lower = city.downcase

              unless address_lower.include?(city_lower)
                result.add_warning(
                  "Geoapify rezultat nije u očekivanom gradu. Traženo: #{city}, Pronađeno: #{best[:address]}",
                  code: :city_mismatch
                )
              end
            end

            result.coordinates = { lat: best[:lat], lng: best[:lng] }
            result.geoapify_data = best
          rescue StandardError => e
            result.add_warning("Geoapify provjera nije uspjela: #{e.message}", code: :geoapify_error)
          end

          result
        end

        def check_bih_boundaries(lat, lng)
          result = ValidationResult.new

          unless Geo::BihBoundaryValidator.inside_bih?(lat, lng)
            result.add_error(
              "Koordinate (#{lat}, #{lng}) nisu unutar granica BiH",
              code: :outside_bih
            )
          end

          result
        end

        def check_geographic_coherence(locations)
          result = ValidationResult.new
          return result if locations.size < 2

          # Izračunaj maksimalnu udaljenost između bilo koje dvije lokacije
          max_distance = 0
          locations.combination(2).each do |loc1, loc2|
            next unless loc1.geocoded? && loc2.geocoded?

            distance = loc1.distance_from(loc2.lat, loc2.lng)
            max_distance = [max_distance, distance].max if distance
          end

          # Upozori ako su lokacije predaleko (>200km)
          if max_distance > 200
            result.add_warning(
              "Lokacije su udaljene do #{max_distance.round}km - iskustvo možda nije praktično u jednom danu",
              code: :large_distance
            )
          end

          result
        end

        def add_suggestions(result, name, city)
          if result.status == :warning
            result.add_suggestion("Koristi WebSearch za dodatnu provjeru: \"#{name} #{city} Bosnia Herzegovina\"")
          end

          if result.warnings.any? { |w| w[:code] == :suspicious_pattern_high }
            result.add_suggestion("Provjeri tačan naziv lokacije na booking.com ili tripadvisor.com")
          end
        end

        def find_all_duplicates
          duplicates = []

          # Grupiši po normaliziranom imenu
          Location.select(:id, :name, :city)
            .group_by { |l| normalize_name(l.name) }
            .each do |normalized, locs|
              next if locs.size < 2

              # Različiti gradovi za isti naziv = potencijalni problem
              cities = locs.map(&:city).uniq
              if cities.size > 1
                duplicates << {
                  name: locs.first.name,
                  records: locs.map { |l| { id: l.id, name: l.name, city: l.city } },
                  issue: "Ista lokacija u različitim gradovima: #{cities.join(', ')}"
                }
              end
            end

          duplicates
        end

        def normalize_name(name)
          name.to_s.downcase
            .gsub(/[čć]/i, "c")
            .gsub(/[žš]/i, "s")
            .gsub(/đ/i, "d")
            .gsub(/[^a-z0-9\s]/, "")
            .squeeze(" ")
            .strip
        end

        def format_duplicate(location, match_type)
          {
            id: location.id,
            name: location.name,
            city: location.city,
            match_type: match_type
          }
        end
      end
    end
  end
end
