# frozen_string_literal: true

module Ai
  class LocationEnricher
    # Generates multilingual descriptions for locations
    class DescriptionGenerator < Base
      LOCALES_PER_BATCH = 5  # ~150 words each = ~750 words output

      # Generate descriptions in multiple languages
      # @param location [Location] The location
      # @param place_data [Hash] Optional Geoapify data
      # @param locales [Array<String>] Locales to generate (defaults to all supported)
      # @return [Hash] Descriptions keyed by locale
      def generate(location, place_data = {}, locales: nil)
        locales ||= supported_locales
        descriptions = {}

        locales.each_slice(LOCALES_PER_BATCH).each_with_index do |batch_locales, batch_index|
          log_info "Generating descriptions batch #{batch_index + 1} for #{location.name}: #{batch_locales.join(', ')}"

          batch_result = generate_batch(location, place_data, batch_locales)
          descriptions.merge!(batch_result) if batch_result.present?
        end

        descriptions
      end

      private

      def generate_batch(location, place_data, locales)
        prompt = build_prompt(location, place_data, locales)

        result = Ai::OpenaiQueue.request(
          prompt: prompt,
          schema: schema_for(locales),
          context: "LocationEnricher:descriptions:#{location.name}"
        )

        result&.dig(:descriptions) || {}
      rescue Ai::OpenaiQueue::RequestError => e
        log_warn "Descriptions generation failed for #{location.name}: #{e.message}"
        {}
      end

      def build_prompt(location, place_data, locales)
        load_prompt("location_enricher/descriptions.md.erb",
          **location_vars(location, place_data),
          locales: locales)
      end

      def schema_for(locales)
        locale_properties = locales.to_h { |loc| [ loc, { type: "string" } ] }
        {
          type: "object",
          properties: {
            descriptions: {
              type: "object",
              properties: locale_properties,
              required: locales,
              additionalProperties: false
            }
          },
          required: %w[descriptions],
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
