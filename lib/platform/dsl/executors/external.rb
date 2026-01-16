# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # External executor - handles external API queries and code introspection
      #
      # Query types:
      # - external_query: Geoapify, geocoding, validation
      # - code_query: code introspection, models, routes
      #
      module External
        class << self
          # Execute external query (Geoapify, geocoding, etc.)
          def execute_external_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :search_pois
              search_pois(filters, operation[:args])
            when :geocode
              geocode_address(filters)
            when :reverse_geocode
              reverse_geocode_coords(filters)
            when :validate_location, :validate
              validate_location(filters)
            when :check_duplicate, :dedupe
              check_duplicate(filters)
            else
              raise ExecutionError, "Nepoznata external operacija: #{operation&.dig(:name)}"
            end
          end

          # Execute code query (introspection)
          def execute_code_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :read_file
              read_file(filters)
            when :search
              search_code(filters, operation[:args]&.first)
            when :grep
              grep_code(filters, operation[:args]&.first)
            when :structure
              show_code_structure(filters)
            when :models
              list_models
            when :routes
              list_routes
            else
              code_overview
            end
          end

          private

          # ===================
          # External API methods
          # ===================

          def search_pois(filters, args)
            city = filters[:city]
            raise ExecutionError, "search_pois zahtijeva filter: city" unless city

            coords = get_city_coordinates(city)
            raise ExecutionError, "Nije moguće pronaći koordinate za grad: #{city}" unless coords

            radius = filters[:radius] || 15_000
            max_results = filters[:limit] || 50
            categories = filters[:categories] || args&.first

            results = Ai::RateLimiter.with_delay(delay: 0.25) do
              geoapify_service.search_nearby(
                lat: coords[:lat],
                lng: coords[:lng],
                radius: radius,
                types: Array(categories).map(&:to_s),
                max_results: max_results
              )
            end

            bih_results = results.select do |place|
              Geo::BihBoundaryValidator.inside_bih?(place[:lat], place[:lng])
            end

            {
              city: city,
              center: coords,
              radius: radius,
              total_found: results.size,
              in_bih: bih_results.size,
              filtered_out: results.size - bih_results.size,
              results: bih_results.map { |p| format_poi_result(p) }
            }
          end

          def geocode_address(filters)
            address = filters[:address] || filters[:query]
            raise ExecutionError, "geocode zahtijeva filter: address" unless address

            results = Ai::RateLimiter.with_delay(delay: 0.25) do
              geoapify_service.text_search(query: address)
            end

            return { address: address, found: false, results: [] } if results.empty?

            formatted = results.map do |r|
              in_bih = Geo::BihBoundaryValidator.inside_bih?(r[:lat], r[:lng])
              {
                name: r[:name],
                address: r[:address],
                lat: r[:lat],
                lng: r[:lng],
                in_bih: in_bih,
                type: r[:primary_type]
              }
            end

            {
              query: address,
              found: true,
              count: formatted.size,
              in_bih_count: formatted.count { |r| r[:in_bih] },
              results: formatted
            }
          end

          def reverse_geocode_coords(filters)
            lat = filters[:lat]
            lng = filters[:lng]
            raise ExecutionError, "reverse_geocode zahtijeva filtere: lat, lng" unless lat && lng

            result = Ai::RateLimiter.with_delay(delay: 0.25) do
              geoapify_service.reverse_geocode(lat: lat.to_f, lng: lng.to_f)
            end

            in_bih = Geo::BihBoundaryValidator.inside_bih?(lat, lng)

            {
              lat: lat.to_f,
              lng: lng.to_f,
              in_bih: in_bih,
              address: result[:formatted],
              city: result[:city] || result[:town] || result[:village],
              country: result[:country],
              country_code: result[:country_code]
            }
          end

          def validate_location(filters)
            lat = filters[:lat]
            lng = filters[:lng]
            raise ExecutionError, "validate_location zahtijeva filtere: lat, lng" unless lat && lng

            lat_f = lat.to_f
            lng_f = lng.to_f
            in_bih = Geo::BihBoundaryValidator.inside_bih?(lat_f, lng_f)

            result = {
              lat: lat_f,
              lng: lng_f,
              in_bih: in_bih,
              valid: in_bih
            }

            unless in_bih
              result[:distance_to_border_km] = Geo::BihBoundaryValidator.distance_to_border(lat_f, lng_f).round(2)
              result[:message] = "Lokacija je van granica Bosne i Hercegovine"
            end

            result
          end

          def check_duplicate(filters)
            name = filters[:name]
            lat = filters[:lat]
            lng = filters[:lng]

            raise ExecutionError, "check_duplicate zahtijeva filter: name ili (lat, lng)" unless name || (lat && lng)

            duplicates = []

            if name
              similar = Location.where("LOWER(name) LIKE ?", "%#{name.downcase}%").limit(10)
              duplicates += similar.map do |loc|
                {
                  id: loc.id,
                  name: loc.name,
                  city: loc.city,
                  match_type: :name,
                  lat: loc.lat,
                  lng: loc.lng
                }
              end
            end

            if lat && lng
              target_lat = lat.to_f
              target_lng = lng.to_f

              nearby = Location.all.select do |loc|
                next false unless loc.lat && loc.lng
                distance = haversine_distance(target_lat, target_lng, loc.lat, loc.lng)
                distance < 0.1
              end.first(10)

              duplicates += nearby.map do |loc|
                {
                  id: loc.id,
                  name: loc.name,
                  city: loc.city,
                  match_type: :proximity,
                  lat: loc.lat,
                  lng: loc.lng,
                  distance_m: (haversine_distance(lat.to_f, lng.to_f, loc.lat, loc.lng) * 1000).round
                }
              end
            end

            {
              query: { name: name, lat: lat, lng: lng }.compact,
              has_duplicates: duplicates.any?,
              count: duplicates.uniq { |d| d[:id] }.size,
              duplicates: duplicates.uniq { |d| d[:id] }
            }
          end

          # Helper methods for external queries

          def geoapify_service
            @geoapify_service ||= GeoapifyService.new
          end

          def get_city_coordinates(city)
            location = Location.where(city: city).first
            return { lat: location.lat, lng: location.lng } if location&.lat && location&.lng

            results = geoapify_service.text_search(query: "#{city}, Bosnia and Herzegovina")
            return nil if results.empty?

            bih_result = results.find { |r| Geo::BihBoundaryValidator.inside_bih?(r[:lat], r[:lng]) }
            return nil unless bih_result

            { lat: bih_result[:lat], lng: bih_result[:lng] }
          end

          def format_poi_result(place)
            {
              place_id: place[:place_id],
              name: place[:name],
              address: place[:address],
              lat: place[:lat],
              lng: place[:lng],
              type: place[:primary_type],
              types: place[:types],
              rating: place[:rating],
              website: place[:website]
            }
          end

          def haversine_distance(lat1, lng1, lat2, lng2)
            r = 6371
            dlat = to_radians(lat2 - lat1)
            dlng = to_radians(lng2 - lng1)
            a = Math.sin(dlat / 2)**2 +
                Math.cos(to_radians(lat1)) * Math.cos(to_radians(lat2)) *
                Math.sin(dlng / 2)**2
            c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
            r * c
          end

          def to_radians(degrees)
            degrees * Math::PI / 180
          end

          # ===================
          # Code introspection methods
          # ===================

          def read_file(filters)
            file_path = filters[:file] || filters[:path]
            raise ExecutionError, "Potreban filter: file ili path" unless file_path

            full_path = Rails.root.join(file_path).to_s
            unless full_path.start_with?(Rails.root.to_s)
              raise ExecutionError, "Pristup fajlovima izvan projekta nije dozvoljen"
            end

            unless File.exist?(full_path)
              raise ExecutionError, "Fajl nije pronađen: #{file_path}"
            end

            content = File.read(full_path)
            lines = content.lines

            start_line = (filters[:from] || 1).to_i - 1
            end_line = filters[:to] ? filters[:to].to_i : lines.size
            selected_lines = lines[start_line...end_line]

            {
              action: :read_file,
              path: file_path,
              total_lines: lines.size,
              showing: "#{start_line + 1}-#{[end_line, lines.size].min}",
              content: selected_lines&.join || "",
              file_type: File.extname(file_path).delete(".")
            }
          end

          def search_code(filters, pattern)
            raise ExecutionError, "Potreban search pattern" unless pattern

            search_path = filters[:path] || "app lib"
            file_type = filters[:type] || "rb"

            results = []
            search_path.split.each do |path|
              full_path = Rails.root.join(path)
              next unless Dir.exist?(full_path)

              Dir.glob(full_path.join("**/*.#{file_type}")).each do |file|
                File.readlines(file).each_with_index do |line, idx|
                  if line.include?(pattern)
                    results << {
                      file: file.sub("#{Rails.root}/", ""),
                      line: idx + 1,
                      content: line.strip.truncate(100)
                    }
                  end
                end
              end
            end

            {
              action: :search_code,
              pattern: pattern,
              file_type: file_type,
              matches: results.size,
              results: results.first(50)
            }
          end

          def grep_code(filters, pattern)
            search_code(filters, pattern)
          end

          def show_code_structure(filters)
            path = filters[:path] || "app"
            full_path = Rails.root.join(path)

            unless Dir.exist?(full_path)
              raise ExecutionError, "Direktorij nije pronađen: #{path}"
            end

            structure = {}
            Dir.glob(full_path.join("**/*")).each do |item|
              next if File.directory?(item)

              relative = item.sub("#{full_path}/", "")
              parts = relative.split("/")
              current = structure

              parts[0...-1].each do |dir|
                current[dir] ||= {}
                current = current[dir]
              end

              current[parts.last] = File.size(item)
            end

            {
              action: :code_structure,
              path: path,
              structure: structure,
              total_files: Dir.glob(full_path.join("**/*")).count { |f| File.file?(f) }
            }
          end

          def list_models
            models = Dir.glob(Rails.root.join("app/models/**/*.rb")).map do |file|
              model_name = File.basename(file, ".rb").camelize
              begin
                model = model_name.constantize
                next unless model < ApplicationRecord

                {
                  name: model_name,
                  table: model.table_name,
                  columns: model.column_names.size,
                  associations: model.reflect_on_all_associations.map(&:name)
                }
              rescue => e
                nil
              end
            end.compact

            {
              action: :list_models,
              count: models.size,
              models: models
            }
          end

          def list_routes
            routes = Rails.application.routes.routes.map do |route|
              {
                verb: route.verb,
                path: route.path.spec.to_s.gsub("(.:format)", ""),
                controller: route.defaults[:controller],
                action: route.defaults[:action]
              }
            end.reject { |r| r[:controller].nil? }

            {
              action: :list_routes,
              count: routes.size,
              routes: routes.first(100)
            }
          end

          def code_overview
            {
              action: :code_overview,
              app: {
                models: Dir.glob(Rails.root.join("app/models/**/*.rb")).size,
                controllers: Dir.glob(Rails.root.join("app/controllers/**/*.rb")).size,
                views: Dir.glob(Rails.root.join("app/views/**/*.erb")).size,
                jobs: Dir.glob(Rails.root.join("app/jobs/**/*.rb")).size,
                mailers: Dir.glob(Rails.root.join("app/mailers/**/*.rb")).size
              },
              lib: {
                platform: Dir.glob(Rails.root.join("lib/platform/**/*.rb")).size,
                services: Dir.glob(Rails.root.join("app/services/**/*.rb")).size
              },
              test: {
                total: Dir.glob(Rails.root.join("test/**/*_test.rb")).size
              },
              config: {
                routes: Rails.application.routes.routes.size,
                initializers: Dir.glob(Rails.root.join("config/initializers/*.rb")).size
              }
            }
          end
        end
      end
    end
  end
end
