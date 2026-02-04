# frozen_string_literal: true

module Ai
  class LocationEnricher
    # Applies generated enrichment data to a location
    class Applicator < Base
      def initialize(location)
        @location = location
      end

      # Apply enrichment data to the location
      # @param enrichment [Hash] Combined enrichment data with :descriptions, :historical_context, :suitable_experiences, :tags, :practical_info
      # @return [void]
      def apply(enrichment)
        apply_translations(enrichment)
        apply_experience_types(enrichment)
        apply_tags(enrichment)
        apply_practical_info(enrichment)
      end

      # Add tags from Geoapify categories
      # @param categories [Array<String>] Geoapify categories
      # @return [void]
      def add_tags_from_categories(categories)
        return if categories.blank?

        category_tags = categories.map do |cat|
          cat.to_s.split(".").last.gsub("_", "-")
        end.uniq.first(3)

        @location.tags = (@location.tags + category_tags).uniq
        @location.save
      end

      private

      attr_reader :location

      def apply_translations(enrichment)
        supported_locales.each do |locale|
          if (desc = enrichment.dig(:descriptions, locale.to_s) || enrichment.dig(:descriptions, locale.to_sym))
            @location.set_translation(:description, desc, locale)
          end

          if (context = enrichment.dig(:historical_context, locale.to_s) || enrichment.dig(:historical_context, locale.to_sym))
            @location.set_translation(:historical_context, context, locale)
          end

          @location.set_translation(:name, @location.name, locale)
        end
      end

      def apply_experience_types(enrichment)
        hints = enrichment[:suitable_experiences].presence

        begin
          classifier = Ai::ExperienceTypeClassifier.new
          result = classifier.classify(@location, dry_run: false, hints: hints)

          if result[:success]
            log_info "Classified with types: #{result[:types].join(', ')}"
          elsif hints.present?
            log_warn "Classifier failed, using hints: #{hints.join(', ')}"
            safely_set_experience_types(hints)
          end
        rescue StandardError => e
          log_error "Experience type classification failed: #{e.message}"
          safely_set_experience_types(hints) if hints.present?
        end
      end

      def safely_set_experience_types(types)
        @location.set_experience_types(types)
      rescue StandardError => e
        log_warn "Could not set experience types: #{e.message}"
      end

      def apply_tags(enrichment)
        return unless enrichment[:tags].present?

        @location.tags = (@location.tags + enrichment[:tags]).uniq
      end

      def apply_practical_info(enrichment)
        return unless enrichment[:practical_info].present?

        @location.audio_tour_metadata ||= {}
        @location.audio_tour_metadata = @location.audio_tour_metadata.merge(
          "practical_info" => enrichment[:practical_info]
        )
      end
    end
  end
end
