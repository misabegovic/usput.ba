# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # Content executor - handles mutations, generation, and audio
      #
      # Query types:
      # - mutation: create/update/delete operations
      # - generation: AI content generation (descriptions, translations, experiences)
      # - audio: audio synthesis for locations
      #
      module Content
        extend Platform::DSL::LLMHelper

        class << self
          # Execute mutation (create, update, delete)
          def execute_mutation(ast)
            action = ast[:action]
            table = ast[:table]

            case action
            when :create
              execute_create(table, ast[:data])
            when :update
              execute_update(table, ast[:filters], ast[:data])
            when :delete
              execute_delete(table, ast[:filters] || ast[:data])
            else
              raise ExecutionError, "Nepoznata mutacija: #{action}"
            end
          end

          # Execute generation (description, translations, experience)
          def execute_generation(ast)
            case ast[:gen_type]
            when :description
              generate_description(ast)
            when :translations
              generate_translations(ast)
            when :experience
              generate_experience(ast)
            else
              raise ExecutionError, "Nepoznat tip generacije: #{ast[:gen_type]}"
            end
          end

          # Execute audio (synthesize, estimate)
          def execute_audio(ast)
            case ast[:action]
            when :synthesize
              synthesize_audio(ast)
            when :estimate
              estimate_audio_cost(ast)
            else
              raise ExecutionError, "Nepoznata audio akcija: #{ast[:action]}"
            end
          end

          private

          # ===================
          # Mutation methods
          # ===================

          def execute_create(table, data)
            model = TableQuery.resolve_model(table)
            validate_mutation_data!(table, data, :create)

            # For locations, run content validation first
            if is_location_table?(table)
              validation_result = validate_location_content(data)
              if validation_result && !validation_result.valid?
                raise ExecutionError, "Validacija nije prošla: #{validation_result.errors.map { |e| e[:message] }.join(', ')}"
              end
              # Log warnings but continue
              if validation_result&.warnings&.any?
                Rails.logger.warn "[DSL::Content] Validation warnings for '#{data[:name]}': #{validation_result.warnings.map { |w| w[:message] }.join(', ')}"
              end
            end

            # For locations, enrich with Geoapify data (coordinates, tags, etc.)
            if is_location_table?(table)
              data = enrich_location_with_geoapify(data)
            end

            # For locations, validate BiH boundary
            if is_location_table?(table) && data[:lat] && data[:lng]
              unless Geo::BihBoundaryValidator.inside_bih?(data[:lat], data[:lng])
                raise ExecutionError, "Lokacija mora biti unutar granica BiH (lat: #{data[:lat]}, lng: #{data[:lng]})"
              end
            end

            # CRITICAL: Require coordinates for locations
            # This prevents creating locations with unknown/wrong coordinates
            if is_location_table?(table) && !(data[:lat].present? && data[:lng].present?)
              raise ExecutionError, "Lokacija '#{data[:name]}' ne može biti kreirana bez koordinata. Geoapify nije pronašao tačnu lokaciju. Koristi explicit lat/lng ili search_pois za pronalazak POI-ja sa koordinatama."
            end

            # For locations, check for existing by coordinates first (find-or-create pattern)
            if is_location_table?(table) && data[:lat] && data[:lng]
              existing = Location.find_by_coordinates_fuzzy(data[:lat], data[:lng])
              if existing
                return {
                  success: true,
                  action: :found_existing,
                  record_type: model.name,
                  record_id: existing.id,
                  message: "Lokacija već postoji na tim koordinatama",
                  data: format_created_record(existing)
                }
              end
            end

            record = model.new(data)

            # Mark as AI-generated for models that support this flag
            if record.respond_to?(:ai_generated=)
              record.ai_generated = true
            end

            unless record.save
              raise ExecutionError, "Kreiranje nije uspjelo: #{record.errors.full_messages.join(', ')}"
            end

            PlatformAuditLog.log_create(record, triggered_by: "platform_dsl")
            PlatformStatistic.invalidate_content_stats

            {
              success: true,
              action: :create,
              record_type: model.name,
              record_id: record.id,
              data: format_created_record(record)
            }
          end

          def execute_update(table, filters, data)
            model = TableQuery.resolve_model(table)
            record = find_record_for_mutation(model, filters)

            # For locations, validate BiH boundary if coordinates are being updated
            if is_location_table?(table) && (data[:lat] || data[:lng])
              new_lat = data[:lat] || record.lat
              new_lng = data[:lng] || record.lng
              unless Geo::BihBoundaryValidator.inside_bih?(new_lat, new_lng)
                raise ExecutionError, "Lokacija mora biti unutar granica BiH (lat: #{new_lat}, lng: #{new_lng})"
              end
            end

            # Capture changes before update
            old_values = data.keys.each_with_object({}) do |key, hash|
              hash[key] = record.send(key) if record.respond_to?(key)
            end

            unless record.update(data)
              raise ExecutionError, "Ažuriranje nije uspjelo: #{record.errors.full_messages.join(', ')}"
            end

            # Build changes hash
            changes = data.keys.each_with_object({}) do |key, hash|
              hash[key.to_s] = [old_values[key], record.send(key)]
            end

            PlatformAuditLog.log_update(record, changes: changes, triggered_by: "platform_dsl")
            PlatformStatistic.invalidate_content_stats

            {
              success: true,
              action: :update,
              record_type: model.name,
              record_id: record.id,
              changes: changes
            }
          end

          def execute_delete(table, filters)
            model = TableQuery.resolve_model(table)
            record = find_record_for_mutation(model, filters)

            PlatformAuditLog.log_delete(record, triggered_by: "platform_dsl")

            # Try soft delete first, fall back to hard delete
            if record.respond_to?(:discard)
              record.discard
            elsif record.respond_to?(:soft_delete)
              record.soft_delete
            else
              record.destroy
            end

            PlatformStatistic.invalidate_content_stats

            {
              success: true,
              action: :delete,
              record_type: model.name,
              record_id: record.id,
              message: "Record deleted"
            }
          end

          def find_record_for_mutation(model, filters)
            raise ExecutionError, "Potreban filter za identifikaciju zapisa (npr. id)" if filters.nil? || filters.empty?

            if filters[:id]
              record = model.find_by(id: filters[:id])
              raise ExecutionError, "#{model.name} sa id=#{filters[:id]} nije pronađen" unless record
              record
            else
              records = TableQuery.send(:apply_filters, model, filters)
              raise ExecutionError, "Nijedan #{model.name} nije pronađen sa zadanim filterima" if records.empty?
              raise ExecutionError, "Pronađeno više zapisa (#{records.count}). Koristi id za preciznu selekciju." if records.count > 1
              records.first
            end
          end

          def validate_mutation_data!(table, data, action)
            if is_location_table?(table) && action == :create
              required = [:name, :city]
              missing = required.select { |f| data[f].blank? }
              raise ExecutionError, "Nedostaju obavezna polja: #{missing.join(', ')}" if missing.any?
            elsif is_experience_table?(table) && action == :create
              required = [:title]
              missing = required.select { |f| data[f].blank? }
              raise ExecutionError, "Nedostaju obavezna polja: #{missing.join(', ')}" if missing.any?
            end
          end

          def is_location_table?(table)
            %w[location locations].include?(table.to_s.downcase)
          end

          def is_experience_table?(table)
            %w[experience experiences].include?(table.to_s.downcase)
          end

          # Validate location content before creation (checks for hallucinations, duplicates, etc.)
          # @param data [Hash] Location data with :name and :city
          # @return [ValidationResult, nil] Validation result or nil if validation disabled
          def validate_location_content(data)
            return nil if data[:skip_validation] # Allow bypassing for tests

            name = data[:name]
            city = data[:city]
            return nil unless name.present? && city.present?

            begin
              require_relative "../content_validator"
              ContentValidator.validate_location(
                name: name,
                city: city,
                lat: data[:lat],
                lng: data[:lng]
              )
            rescue StandardError => e
              Rails.logger.warn "[DSL::Content] Content validation failed: #{e.message}"
              nil # Don't block creation if validation fails
            end
          end

          # Enrich location data using Geoapify
          # Uses name + city to find accurate coordinates, tags, and other metadata
          #
          # @param data [Hash] Location data with at least :name and :city
          # @return [Hash] Enriched data with Geoapify information
          def enrich_location_with_geoapify(data)
            return data if data[:skip_geoapify] # Allow bypassing for tests

            name = data[:name]
            city = data[:city]
            return data unless name.present?

            begin
              service = GeoapifyService.new
              query = city.present? ? "#{name}, #{city}, Bosnia and Herzegovina" : "#{name}, Bosnia and Herzegovina"

              results = service.text_search(query: query)
              return data if results.empty?

              # Filter results to only include locations within BiH boundaries
              # This is critical because Geoapify might return results from other countries
              bih_results = results.select do |r|
                r[:lat].present? && r[:lng].present? &&
                  Geo::BihBoundaryValidator.inside_bih?(r[:lat], r[:lng])
              end

              if bih_results.empty?
                Rails.logger.warn "[DSL::Content] Geoapify returned no results within BiH for '#{name}'"
                return data
              end

              # Find best match - prefer exact name match, then first result
              best_match = bih_results.find { |r| r[:name]&.downcase&.include?(name.downcase) } || bih_results.first

              enriched = data.dup

              # Use Geoapify coordinates if not explicitly provided
              unless data[:lat].present? && data[:lng].present?
                # CRITICAL: Validate that the result is actually in the expected city
                # Geoapify text_search often returns wrong locations when POI doesn't exist
                if city.present? && best_match[:address].present?
                  address_lower = best_match[:address].to_s.downcase
                  city_lower = city.downcase

                  # Check if the address contains the city name (with some flexibility for diacritics)
                  city_normalized = city_lower.gsub(/[čćžšđ]/, 'c' => 'c', 'ć' => 'c', 'ž' => 'z', 'š' => 's', 'đ' => 'd')
                  address_normalized = address_lower.gsub(/[čćžšđ]/, 'c' => 'c', 'ć' => 'c', 'ž' => 'z', 'š' => 's', 'đ' => 'd')

                  unless address_normalized.include?(city_normalized) || address_lower.include?(city_lower)
                    Rails.logger.warn "[DSL::Content] Geoapify result for '#{name}' is not in expected city '#{city}'. Address: #{best_match[:address]}. Skipping coordinates."
                    # Don't use coordinates from wrong city - return data without lat/lng enrichment
                    return data
                  end
                end

                enriched[:lat] = best_match[:lat]
                enriched[:lng] = best_match[:lng]
              end

              # Try to get more detailed place info if we have place_id
              place_details = nil
              if best_match[:place_id].present?
                begin
                  place_details = service.get_place_details(best_match[:place_id])
                rescue StandardError => e
                  Rails.logger.debug "[DSL::Content] Could not get place details: #{e.message}"
                end
              end

              # Merge tags from Geoapify categories (from details or text_search)
              all_types = []
              all_types += Array(place_details[:types]) if place_details.present?
              all_types += Array(best_match[:types])
              all_types += [best_match[:primary_type]] if best_match[:primary_type].present?

              if all_types.present?
                # Clean up tags - remove dots, underscores, get meaningful parts
                geoapify_tags = all_types.flat_map do |t|
                  parts = t.to_s.split(".")
                  # Include both full category and last part
                  [parts.last, parts[-2]].compact.map { |p| p.gsub("_", " ") }
                end.compact.uniq.reject(&:blank?)

                existing_tags = Array(data[:tags])
                enriched[:tags] = (existing_tags + geoapify_tags).uniq.first(15) # Limit to 15 tags
              end

              # Infer budget from price_level if not set
              unless data[:budget].present?
                price_level = place_details&.dig(:price_level) || best_match[:price_level]
                if price_level.present?
                  enriched[:budget] = case price_level.to_s.to_sym
                  when :low, :cheap, :inexpensive then :low
                  when :high, :expensive then :high
                  else :medium
                  end
                end
              end

              # Infer seasons based on location type (outdoor activities are seasonal)
              unless data[:seasons].present?
                enriched[:seasons] = infer_seasons_from_types(all_types)
              end

              Rails.logger.info "[DSL::Content] Enriched location '#{name}' with Geoapify: lat=#{enriched[:lat]}, lng=#{enriched[:lng]}, tags=#{enriched[:tags]&.join(', ')}"
              enriched
            rescue StandardError => e
              Rails.logger.warn "[DSL::Content] Geoapify enrichment failed for '#{name}': #{e.message}"
              data # Return original data if Geoapify fails
            end
          end

          # Infer appropriate seasons based on location types
          # @param types [Array<String>] Location types/categories
          # @return [Array<String>] Inferred seasons (empty = year-round)
          def infer_seasons_from_types(types)
            return [] if types.blank?

            type_str = types.join(" ").downcase

            # Outdoor/summer activities
            if type_str.match?(/beach|swimming|water_park|rafting|kayak|outdoor/)
              return %w[spring summer]
            end

            # Winter activities
            if type_str.match?(/ski|ice_rink|winter/)
              return %w[winter]
            end

            # Nature activities (best in spring/summer/fall)
            if type_str.match?(/hiking|mountain|peak|trail|nature|forest|national_park/)
              return %w[spring summer fall]
            end

            # Indoor activities - year-round
            [] # Empty means year-round
          end

          def format_created_record(record)
            case record
            when Location
              {
                id: record.id,
                name: record.name,
                city: record.city,
                lat: record.lat,
                lng: record.lng,
                tags: record.tags,
                budget: record.budget,
                seasons: record.seasons,
                experience_types: record.experience_types.pluck(:key),
                description: record.description&.truncate(100)
              }
            when Experience
              {
                id: record.id,
                title: record.title,
                description: record.description&.truncate(100),
                estimated_duration: record.estimated_duration,
                formatted_duration: record.formatted_duration,
                seasons: record.seasons,
                locations_count: record.locations_count
              }
            else
              record.attributes.slice("id", "name", "title", "created_at")
            end
          end

          # ===================
          # Generation methods
          # ===================

          def generate_description(ast)
            model = TableQuery.resolve_model(ast[:table])
            record = find_record_for_mutation(model, ast[:filters])
            style = ast[:style] || "informative"

            unless record.respond_to?(:description)
              raise ExecutionError, "#{model.name} nema polje 'description'"
            end

            prompt = build_description_prompt(record, style)
            description = generate_with_llm(prompt)

            old_description = record.description
            record.update!(description: description)

            PlatformAuditLog.log_update(
              record,
              changes: { "description" => [old_description, description] },
              triggered_by: "platform_dsl_generation"
            )

            {
              success: true,
              action: :generate_description,
              record_type: model.name,
              record_id: record.id,
              style: style,
              description: description.truncate(200)
            }
          end

          def generate_translations(ast)
            model = TableQuery.resolve_model(ast[:table])
            record = find_record_for_mutation(model, ast[:filters])
            locales = ast[:locales]

            unless record.respond_to?(:set_translation)
              raise ExecutionError, "#{model.name} ne podržava prijevode"
            end

            valid_locales = Translation::SUPPORTED_LOCALES
            invalid = locales - valid_locales
            raise ExecutionError, "Nepodržani jezici: #{invalid.join(', ')}" if invalid.any?

            translatable_fields = if record.class.respond_to?(:translatable_fields)
              record.class.translatable_fields
            else
              [:name, :description].select { |f| record.respond_to?(f) }
            end

            translations_created = []

            locales.each do |locale|
              translatable_fields.each do |field|
                source_text = record.send(field)
                next if source_text.blank?

                prompt = build_translation_prompt(source_text, locale, field)
                translated = generate_with_llm(prompt)

                record.set_translation(field, translated, locale)
                translations_created << { locale: locale, field: field }
              end
            end

            PlatformAuditLog.create!(
              action: "update",
              record_type: model.name,
              record_id: record.id,
              change_data: { translations_added: translations_created },
              triggered_by: "platform_dsl_generation"
            )

            {
              success: true,
              action: :generate_translations,
              record_type: model.name,
              record_id: record.id,
              locales: locales,
              fields_translated: translatable_fields,
              translations_count: translations_created.size
            }
          end

          def generate_experience(ast)
            location_ids = ast[:location_ids]
            raise ExecutionError, "Potrebne su bar 2 lokacije za generisanje iskustva" if location_ids.size < 2

            locations = Location.where(id: location_ids).to_a
            # Maintain order from input
            locations = location_ids.map { |id| locations.find { |l| l.id == id } }.compact
            missing = location_ids - locations.map(&:id)
            raise ExecutionError, "Lokacije nisu pronađene: #{missing.join(', ')}" if missing.any?

            prompt = build_experience_prompt(locations)
            experience_data = generate_experience_with_llm(prompt, locations)

            # Calculate realistic duration based on distances and visit time
            duration_minutes = calculate_experience_duration(locations, experience_data[:duration_hours])

            # Infer seasons from locations
            experience_seasons = infer_experience_seasons(locations)

            experience = Experience.new(
              title: experience_data[:title],
              description: experience_data[:description],
              estimated_duration: duration_minutes,
              seasons: experience_seasons,
              ai_generated: true
            )

            unless experience.save
              raise ExecutionError, "Kreiranje iskustva nije uspjelo: #{experience.errors.full_messages.join(', ')}"
            end

            locations.each_with_index do |loc, idx|
              experience.experience_locations.create!(location: loc, position: idx + 1)
            end

            PlatformAuditLog.log_create(experience, triggered_by: "platform_dsl_generation")
            PlatformStatistic.invalidate_content_stats

            {
              success: true,
              action: :generate_experience,
              experience_id: experience.id,
              title: experience.title,
              locations_count: locations.size,
              estimated_duration: duration_minutes,
              formatted_duration: experience.formatted_duration,
              seasons: experience_seasons,
              description: experience.description&.truncate(150)
            }
          end

          # Calculate realistic experience duration based on:
          # - Travel time between locations (driving ~60km/h average with stops)
          # - Visit time per location (30-60min depending on type)
          # - Buffer time for transitions
          #
          # @param locations [Array<Location>] Ordered list of locations
          # @param llm_estimate [Integer, nil] LLM's estimate in hours (used as minimum)
          # @return [Integer] Duration in minutes
          def calculate_experience_duration(locations, llm_estimate = nil)
            return (llm_estimate || 2) * 60 if locations.size < 2

            total_distance_km = 0
            total_visit_time = 0

            locations.each_cons(2) do |loc1, loc2|
              if loc1.geocoded? && loc2.geocoded?
                distance = loc1.distance_from(loc2.lat, loc2.lng)
                total_distance_km += distance if distance
              end
            end

            # Visit time per location (base 30min + extra for museums/historical sites)
            locations.each do |loc|
              visit_time = 30 # Base visit time
              tags = loc.tags.join(" ").downcase

              if tags.match?(/museum|gallery|historical|castle|fort|monastery/)
                visit_time = 60 # Longer visit for cultural sites
              elsif tags.match?(/restaurant|cafe|catering/)
                visit_time = 45 # Meal time
              elsif tags.match?(/viewpoint|memorial|monument/)
                visit_time = 20 # Quick stops
              end

              total_visit_time += visit_time
            end

            # Travel time: assume 50km/h average (accounting for local roads, stops)
            travel_time_minutes = (total_distance_km / 50.0 * 60).round

            # Buffer time (15min per transition)
            buffer_time = (locations.size - 1) * 15

            calculated_duration = travel_time_minutes + total_visit_time + buffer_time

            # Use LLM estimate as a sanity check (minimum)
            llm_minutes = (llm_estimate || 0) * 60
            [calculated_duration, llm_minutes, 60].max # At least 1 hour
          end

          # Infer experience seasons from location seasons
          # Experience is available when ALL locations are available
          #
          # @param locations [Array<Location>] Locations in the experience
          # @return [Array<String>] Common seasons (empty = year-round)
          def infer_experience_seasons(locations)
            all_seasons = Location::SEASONS

            # Collect seasons from each location
            location_seasons = locations.map(&:seasons)

            # If any location is year-round (empty seasons), use all seasons for intersection
            location_seasons = location_seasons.map { |s| s.empty? ? all_seasons : s }

            # Find intersection - experience available only when all locations are available
            common_seasons = location_seasons.reduce(all_seasons) { |acc, s| acc & s }

            # If all seasons are available, return empty (year-round)
            common_seasons.sort == all_seasons.sort ? [] : common_seasons
          end

          # generate_with_llm is provided by LLMHelper

          def build_description_prompt(record, style)
            context = case record
            when Location
              "lokacija u Bosni i Hercegovini: #{record.name}, grad: #{record.city}"
            when Experience
              "turističko iskustvo: #{record.title}"
            else
              "#{record.class.name}: #{record.try(:name) || record.try(:title)}"
            end

            style_instruction = case style.to_s.downcase
            when "vivid"
              "Koristi živopisan, emotivan jezik koji inspiriše posjetioce."
            when "formal"
              "Koristi formalan, informativan ton pogodan za vodiče."
            when "casual"
              "Koristi opušten, prijateljski ton."
            else
              "Koristi informativan, ali privlačan ton."
            end

            <<~PROMPT
              Napiši opis za #{context}.

              #{style_instruction}

              Pravila:
              - Piši na bosanskom jeziku (ijekavica)
              - Opis treba biti 2-3 paragrafa (150-250 riječi)
              - Uključi historijski kontekst ako je relevantan
              - Fokusiraj se na ono što čini ovo mjesto posebnim
              - Ne koristi klišeje poput "raj na zemlji" ili "must-see"

              Vrati SAMO tekst opisa, bez naslova ili dodatnih komentara.
            PROMPT
          end

          def build_translation_prompt(text, locale, field)
            locale_name = {
              "en" => "engleski",
              "de" => "njemački",
              "fr" => "francuski",
              "es" => "španski",
              "it" => "italijanski",
              "hr" => "hrvatski",
              "sr" => "srpski",
              "sl" => "slovenski",
              "cs" => "češki",
              "sk" => "slovački",
              "pl" => "poljski",
              "nl" => "holandski",
              "pt" => "portugalski",
              "tr" => "turski",
              "ar" => "arapski"
            }[locale.to_s] || locale

            <<~PROMPT
              Prevedi sljedeći tekst na #{locale_name} jezik.

              Originalni tekst (#{field}):
              #{text}

              Pravila:
              - Zadrži ton i stil originala
              - Zadrži nazive mjesta i lokacija nepromijenjene
              - Za hrvatski koristi ijekavicu
              - Za srpski koristi ćirilicu samo ako je to standardno

              Vrati SAMO preveden tekst, bez dodatnih komentara.
            PROMPT
          end

          def build_experience_prompt(locations)
            location_list = locations.map do |loc|
              "- #{loc.name} (#{loc.city}): #{loc.description&.truncate(100) || 'bez opisa'}"
            end.join("\n")

            <<~PROMPT
              Kreiraj turističko iskustvo koje povezuje sljedeće lokacije:

              #{location_list}

              Vrati JSON format:
              {
                "title": "Naslov iskustva (kreativan, privlačan)",
                "description": "Opis iskustva (2-3 paragrafa, opisuje put i šta posjetilac može očekivati)",
                "duration_hours": broj_sati_potrebnih
              }

              Pravila:
              - Piši na bosanskom jeziku (ijekavica)
              - Naslov treba biti kratak i pamtljiv
              - Opis treba logično povezati lokacije u priču
              - Procijeni realno trajanje bazirano na broju lokacija

              Vrati SAMO JSON, bez dodatnog teksta.
            PROMPT
          end

          def generate_experience_with_llm(prompt, locations)
            response = generate_with_llm(prompt)

            # Extract JSON from response (may be wrapped in markdown code blocks)
            json_str = extract_json_from_response(response)

            begin
              data = JSON.parse(json_str, symbolize_names: true)
              {
                title: data[:title] || "Iskustvo: #{locations.first.city}",
                description: data[:description] || "Iskustvo koje uključuje #{locations.size} lokacija.",
                duration_hours: data[:duration_hours] || locations.size
              }
            rescue JSON::ParserError
              # If JSON parsing still fails, try to extract meaningful content
              {
                title: "Iskustvo: #{locations.map(&:city).uniq.join(' - ')}",
                description: clean_llm_response(response).truncate(500),
                duration_hours: locations.size
              }
            end
          end

          # Extract JSON from LLM response that may include markdown code blocks
          def extract_json_from_response(response)
            # Remove markdown code blocks (```json ... ``` or ``` ... ```)
            cleaned = response.gsub(/```(?:json)?\s*\n?/i, "").strip

            # Try to find JSON object in response
            if match = cleaned.match(/\{[\s\S]*\}/)
              match[0]
            else
              cleaned
            end
          end

          # Clean LLM response for use as plain text
          def clean_llm_response(response)
            response
              .gsub(/```(?:json)?\s*\n?/i, "")  # Remove code blocks
              .gsub(/^\s*\{[\s\S]*\}\s*$/m, "") # Remove JSON objects
              .gsub(/\n{3,}/, "\n\n")           # Normalize whitespace
              .strip
          end

          # ===================
          # Audio methods
          # ===================

          def synthesize_audio(ast)
            model = TableQuery.resolve_model(ast[:table])
            raise ExecutionError, "Audio sinteza je dostupna samo za lokacije" unless model == Location

            record = find_record_for_mutation(model, ast[:filters])
            locale = ast[:locale] || "bs"
            voice = ast[:voice]

            if voice.present?
              voice_id = find_voice_id(voice)
              Setting.set("tts.elevenlabs_voice_id", voice_id) if voice_id
            end

            generator = Ai::AudioTourGenerator.new(record)
            result = generator.generate(locale: locale, force: false)

            PlatformAuditLog.create!(
              action: "create",
              record_type: "AudioTour",
              record_id: record.audio_tours.find_by(locale: locale)&.id,
              change_data: { location_id: record.id, locale: locale },
              triggered_by: "platform_dsl_audio"
            )

            {
              success: true,
              action: :synthesize_audio,
              location_id: record.id,
              location_name: record.name,
              locale: locale,
              status: result[:status],
              duration: result[:duration_estimate],
              audio_info: result[:audio_info]
            }
          rescue Ai::AudioTourGenerator::GenerationError => e
            raise ExecutionError, "Audio sinteza nije uspjela: #{e.message}"
          end

          def estimate_audio_cost(ast)
            model = TableQuery.resolve_model(ast[:table])
            raise ExecutionError, "Procjena troškova je dostupna samo za lokacije" unless model == Location

            records = TableQuery.send(:apply_filters, model, ast[:filters])

            if ast[:filters][:missing_audio]
              records = records.select { |loc| !loc.audio_tours.with_audio.exists? }
            end

            chars_per_tour = 4000
            cost_per_1000_chars = 0.30

            total_locations = records.count
            total_chars = total_locations * chars_per_tour
            estimated_cost = (total_chars / 1000.0) * cost_per_1000_chars

            by_city = records.group_by(&:city).transform_values(&:count)

            {
              action: :estimate_audio_cost,
              total_locations: total_locations,
              estimated_characters: total_chars,
              estimated_cost_usd: estimated_cost.round(2),
              cost_per_location: (estimated_cost / [total_locations, 1].max).round(2),
              by_city: by_city,
              notes: [
                "Procjena bazirana na prosječnom skriptu od #{chars_per_tour} karaktera",
                "ElevenLabs cijena: ~$#{cost_per_1000_chars}/1000 karaktera",
                "Stvarni troškovi mogu varirati ovisno o dužini opisa"
              ]
            }
          end

          def find_voice_id(voice_name)
            voices = Ai::AudioTourGenerator::ELEVENLABS_VOICES
            match = voices.find { |id, info| info[:name].downcase == voice_name.downcase }
            match&.first
          end
        end
      end
    end
  end
end
