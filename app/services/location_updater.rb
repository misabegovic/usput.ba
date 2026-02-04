# frozen_string_literal: true

# Service for updating locations with proper experience type handling
#
# Replaces implicit callback behavior with explicit service object pattern.
# Use this instead of location.update! when changing suitable_experiences.
#
# Usage:
#   result = LocationUpdater.new(location,
#     name: "Updated Name",
#     suitable_experiences: ["nature", "adventure"]
#   ).call
#
#   updated_location = result.location if result.success?
#
class LocationUpdater
  attr_reader :location, :errors

  def initialize(location, attributes = {})
    @location = location
    @attributes = attributes.to_h.with_indifferent_access
    @experience_types, @experience_types_changed = extract_experience_types
    @errors = []
  end

  # Update the location with experience types
  # @return [LocationUpdater] self for chaining
  def call
    ActiveRecord::Base.transaction do
      update_location
      update_experience_types if success? && @experience_types_changed
    end
    self
  rescue ActiveRecord::RecordInvalid => e
    @errors << e.message
    self
  rescue StandardError => e
    @errors << "Unexpected error: #{e.message}"
    self
  end

  def success?
    @errors.empty?
  end

  def failure?
    !success?
  end

  private

  def update_location
    # Remove experience_types from attributes - we handle them separately
    location_attrs = @attributes.except(:suitable_experiences, :experience_types)

    return if location_attrs.empty? && !@experience_types_changed

    unless @location.update(location_attrs)
      @errors.concat(@location.errors.full_messages)
    end
  end

  def update_experience_types
    @location.set_experience_types(@experience_types)
  rescue StandardError => e
    @errors << "Failed to set experience types: #{e.message}"
  end

  def extract_experience_types
    if @attributes.key?(:suitable_experiences) || @attributes.key?(:experience_types)
      exp_types = @attributes[:suitable_experiences] || @attributes[:experience_types]
      types = if exp_types.blank?
                []
      else
                Array(exp_types).map(&:to_s).map(&:strip).map(&:downcase).reject(&:blank?).uniq
      end
      [ types, true ]
    else
      [ [], false ]
    end
  end
end
