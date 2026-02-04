# frozen_string_literal: true

module Ai
  # Automatically classifies locations by experience types using AI
  # Used to retroactively populate missing experience types
  class ExperienceTypeClassifier
    include Concerns::ErrorReporting
    include PromptHelper

    class ClassificationError < StandardError; end

    # Classify a single location and add experience types
    # @param location [Location] Location to classify
    # @param dry_run [Boolean] If true, don't save changes
    # @param hints [Array<String>] Optional hints from initial enrichment
    # @return [Hash] Classification result
    def classify(location, dry_run: false, hints: nil)
      log_info "Classifying #{location.name} (ID: #{location.id})"
      if hints.present?
        log_info "  Using hints: #{hints.join(', ')}"
      end

      # Get classification from AI
      types = ai_classify_location(location, hints)

      if types.blank?
        log_warn "No types classified for #{location.name}"
        return { success: false, location_id: location.id, types: [], error: "No types returned" }
      end

      unless dry_run
        # Add experience types
        types.each do |type_key|
          begin
            location.add_experience_type(type_key)
            log_info "  Added type: #{type_key}"
          rescue StandardError => e
            log_warn "  Failed to add type '#{type_key}': #{e.message}"
          end
        end
      end

      {
        success: true,
        location_id: location.id,
        location_name: location.name,
        types: types,
        dry_run: dry_run
      }
    rescue StandardError => e
      log_error "Classification failed for #{location.name}: #{e.message}"
      {
        success: false,
        location_id: location.id,
        location_name: location.name,
        types: [],
        error: e.message
      }
    end

    # Classify multiple locations in batch
    # @param locations [ActiveRecord::Relation, Array<Location>] Locations to classify
    # @param dry_run [Boolean] If true, don't save changes
    # @return [Hash] Batch results
    def classify_batch(locations, dry_run: false)
      results = {
        total: locations.count,
        processed: 0,
        successful: 0,
        failed: 0,
        types_added: Hash.new(0),
        errors: []
      }

      locations.find_each do |location|
        result = classify(location, dry_run: dry_run)
        results[:processed] += 1

        if result[:success]
          results[:successful] += 1
          result[:types].each { |type| results[:types_added][type] += 1 }
        else
          results[:failed] += 1
          results[:errors] << { location_id: location.id, error: result[:error] }
        end

        # Progress reporting
        if results[:processed] % 10 == 0
          log_info "Progress: #{results[:processed]}/#{results[:total]} (#{results[:successful]} successful)"
        end
      end

      log_info "Batch complete: #{results[:successful]}/#{results[:total]} successful"
      results
    end

    # Classify all locations without experience types
    # @param dry_run [Boolean] If true, don't save changes
    # @param limit [Integer, nil] Limit number of locations to process
    # @return [Hash] Results
    def classify_missing(dry_run: false, limit: nil)
      locations = Location.left_joins(:location_experience_types)
        .where(location_experience_types: { id: nil })
        .distinct

      locations = locations.limit(limit) if limit.present?

      log_info "Found #{locations.count} locations without experience types"

      classify_batch(locations, dry_run: dry_run)
    end

    private

    def ai_classify_location(location, hints = nil)
      user_prompt = build_classification_prompt(location, hints)
      full_prompt = "#{system_prompt}\n\n#{user_prompt}"

      # Use OpenaiQueue for rate limiting and retry logic
      result = Ai::OpenaiQueue.request(
        prompt: full_prompt,
        schema: nil,
        context: "ExperienceTypeClassifier:#{location.name}"
      )

      parse_types_from_response(result.to_s)
    rescue Ai::OpenaiQueue::RequestError => e
      log_error "AI request failed: #{e.message}"
      []
    end

    def system_prompt
      load_prompt("experience_type_classifier/system.md.erb",
        available_types: available_types_description)
    end

    def build_classification_prompt(location, hints = nil)
      load_prompt("experience_type_classifier/classify.md.erb",
        name: location.name,
        city: location.city,
        category: location.category_name,
        description_bs: location.translate(:description, :bs),
        description_en: location.translate(:description, :en),
        tags: location.tags,
        hints: hints)
    end

    def parse_types_from_response(content)
      return [] if content.blank?

      # Extract type keys from response
      types = content.downcase
        .split(/[,\n]/)
        .map(&:strip)
        .reject(&:blank?)
        .select { |t| valid_type?(t) }
        .uniq

      types
    end

    def valid_type?(type_key)
      ExperienceType.find_by("LOWER(key) = ?", type_key.downcase).present?
    end

    def available_types_description
      ExperienceType.active.ordered.map do |et|
        "- #{et.key}: #{et.name}#{et.description.present? ? ' - ' + et.description.truncate(100) : ''}"
      end.join("\n")
    end

    def log_info(message)
      Rails.logger.info "[ExperienceTypeClassifier] #{message}"
    end

    def log_warn(message)
      Rails.logger.warn "[ExperienceTypeClassifier] #{message}"
    end

    def log_error(message)
      Rails.logger.error "[ExperienceTypeClassifier] #{message}"
    end
  end
end
