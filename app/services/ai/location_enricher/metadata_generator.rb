# frozen_string_literal: true

module Ai
  class LocationEnricher
    # Generates metadata for locations: experience types, tags, practical info
    class MetadataGenerator < Base
      SCHEMA = {
        type: "object",
        properties: {
          suitable_experiences: {
            type: "array",
            items: { type: "string" },
            description: "Experience types this location is suitable for"
          },
          tags: {
            type: "array",
            items: { type: "string" },
            description: "Relevant tags in English (lowercase, hyphens instead of spaces)"
          },
          practical_info: {
            type: "object",
            properties: {
              best_time: { type: "string", description: "Best time to visit (morning, afternoon, evening, any)" },
              duration_minutes: { type: "integer", description: "Suggested visit duration in minutes" },
              tips: { type: "array", items: { type: "string" }, description: "Practical tips for visitors" }
            },
            required: %w[best_time duration_minutes tips],
            additionalProperties: false
          }
        },
        required: %w[suitable_experiences tags practical_info],
        additionalProperties: false
      }.freeze

      # Generate metadata for a location
      # @param location [Location] The location to generate metadata for
      # @param place_data [Hash] Optional Geoapify data
      # @return [Hash] Generated metadata
      def generate(location, place_data = {})
        log_info "Generating metadata for #{location.name}"

        prompt = build_prompt(location, place_data)

        Ai::OpenaiQueue.request(
          prompt: prompt,
          schema: SCHEMA,
          context: "LocationEnricher:metadata:#{location.name}"
        )
      rescue Ai::OpenaiQueue::RequestError => e
        log_warn "Metadata generation failed for #{location.name}: #{e.message}"
        {}
      end

      private

      def build_prompt(location, place_data)
        load_prompt("location_enricher/metadata.md.erb",
          **location_vars(location, place_data),
          experience_types: supported_experience_types.join(", "))
      end

      def location_vars(location, place_data)
        {
          name: location.name,
          city: location.city,
          category: place_data[:categories]&.first || location.category_name,
          categories: place_data[:categories]&.join(", "),
          address: place_data[:formatted] || place_data[:address_line1],
          lat: location.lat,
          lng: location.lng,
          cultural_context: cultural_context
        }
      end
    end
  end
end
