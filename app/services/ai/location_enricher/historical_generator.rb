# frozen_string_literal: true

module Ai
  class LocationEnricher
    # Generates multilingual historical context for locations
    class HistoricalGenerator < Base
      LOCALES_PER_BATCH = 3  # ~300 words each = ~900 words output

      # Generate historical context in multiple languages
      # @param location [Location] The location
      # @param place_data [Hash] Optional Geoapify data
      # @param locales [Array<String>] Locales to generate (defaults to all supported)
      # @return [Hash] Historical context keyed by locale
      def generate(location, place_data = {}, locales: nil)
        locales ||= supported_locales
        historical_context = {}

        locales.each_slice(LOCALES_PER_BATCH).each_with_index do |batch_locales, batch_index|
          log_info "Generating historical context batch #{batch_index + 1} for #{location.name}: #{batch_locales.join(', ')}"

          batch_result = generate_batch(location, place_data, batch_locales)
          historical_context.merge!(batch_result) if batch_result.present?
        end

        historical_context
      end

      private

      def generate_batch(location, place_data, locales)
        prompt = build_prompt(location, place_data, locales)

        result = Ai::OpenaiQueue.request(
          prompt: prompt,
          schema: schema_for(locales),
          context: "LocationEnricher:history:#{location.name}"
        )

        result&.dig(:historical_context) || {}
      rescue Ai::OpenaiQueue::RequestError => e
        log_warn "Historical context generation failed for #{location.name}: #{e.message}"
        {}
      end

      def build_prompt(location, place_data, locales)
        load_prompt("location_enricher/historical_context.md.erb",
          **location_vars(location, place_data),
          locales: locales)
      end

      def schema_for(locales)
        locale_properties = locales.to_h { |loc| [ loc, { type: "string" } ] }
        {
          type: "object",
          properties: {
            historical_context: {
              type: "object",
              properties: locale_properties,
              required: locales,
              additionalProperties: false
            }
          },
          required: %w[historical_context],
          additionalProperties: false
        }
      end

      def location_vars(location, place_data)
        {
          name: location.name,
          city: location.city,
          category: place_data[:categories]&.first || location.category_name,
          categories: place_data[:categories]&.join(", "),
          address: place_data[:formatted] || place_data[:address_line1],
          cultural_context: cultural_context
        }
      end
    end
  end
end
