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
        extend LLMHelper

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

            # For locations, validate BiH boundary
            if is_location_table?(table) && data[:lat] && data[:lng]
              unless Geo::BihBoundaryValidator.inside_bih?(data[:lat], data[:lng])
                raise ExecutionError, "Lokacija mora biti unutar granica BiH (lat: #{data[:lat]}, lng: #{data[:lng]})"
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

          def format_created_record(record)
            case record
            when Location
              {
                id: record.id,
                name: record.name,
                city: record.city,
                lat: record.lat,
                lng: record.lng,
                description: record.description&.truncate(100)
              }
            when Experience
              {
                id: record.id,
                title: record.title,
                description: record.description&.truncate(100)
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

            locations = Location.where(id: location_ids)
            missing = location_ids - locations.pluck(:id)
            raise ExecutionError, "Lokacije nisu pronađene: #{missing.join(', ')}" if missing.any?

            prompt = build_experience_prompt(locations)
            experience_data = generate_experience_with_llm(prompt, locations)

            duration_minutes = (experience_data[:duration_hours] || locations.size) * 60
            experience = Experience.new(
              title: experience_data[:title],
              description: experience_data[:description],
              estimated_duration: duration_minutes,
              ai_generated: true
            )

            unless experience.save
              raise ExecutionError, "Kreiranje iskustva nije uspjelo: #{experience.errors.full_messages.join(', ')}"
            end

            locations.each_with_index do |loc, idx|
              experience.experience_locations.create!(location: loc, position: idx + 1)
            end

            PlatformAuditLog.log_create(experience, triggered_by: "platform_dsl_generation")

            {
              success: true,
              action: :generate_experience,
              experience_id: experience.id,
              title: experience.title,
              locations_count: locations.size,
              description: experience.description&.truncate(150)
            }
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

            begin
              data = JSON.parse(response, symbolize_names: true)
              {
                title: data[:title] || "Iskustvo: #{locations.first.city}",
                description: data[:description] || "Iskustvo koje uključuje #{locations.size} lokacija.",
                duration_hours: data[:duration_hours] || locations.size
              }
            rescue JSON::ParserError
              {
                title: "Iskustvo: #{locations.map(&:city).uniq.join(' - ')}",
                description: response.truncate(500),
                duration_hours: locations.size
              }
            end
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
