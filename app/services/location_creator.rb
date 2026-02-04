# frozen_string_literal: true

# Service for creating locations with proper experience type handling
#
# Replaces implicit callback behavior with explicit service object pattern.
# Use this instead of Location.create! when setting suitable_experiences.
#
# Usage:
#   result = LocationCreator.new(
#     name: "Stari Most",
#     city: "Mostar",
#     lat: 43.337,
#     lng: 17.815,
#     suitable_experiences: ["culture", "history"]
#   ).call
#
#   location = result.location if result.success?
#
class LocationCreator
  attr_reader :location, :errors

  def initialize(attributes = {})
    @attributes = attributes.to_h.with_indifferent_access
    @experience_types = extract_experience_types
    @errors = []
  end

  # Create the location with experience types
  # @return [LocationCreator] self for chaining
  def call
    ActiveRecord::Base.transaction do
      create_location
      assign_experience_types if success? && @experience_types.present?
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
    @errors.empty? && @location&.persisted?
  end

  def failure?
    !success?
  end

  private

  def create_location
    # Remove experience_types from attributes - we handle them separately
    location_attrs = @attributes.except(:suitable_experiences, :experience_types)

    @location = Location.new(location_attrs)

    # Skip the callback by not setting suitable_experiences via setter
    unless @location.save
      @errors.concat(@location.errors.full_messages)
    end
  end

  def assign_experience_types
    @location.set_experience_types(@experience_types)
  end

  def extract_experience_types
    exp_types = @attributes[:suitable_experiences] || @attributes[:experience_types]
    return [] if exp_types.blank?

    Array(exp_types).map(&:to_s).map(&:strip).map(&:downcase).reject(&:blank?).uniq
  end
end
