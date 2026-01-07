# frozen_string_literal: true

# Concern for models that use UUID for public identification
# This provides secure, non-enumerable identifiers for use in URLs and APIs
#
# Usage:
#   class Location < ApplicationRecord
#     include Identifiable
#   end
#
# This will:
#   - Generate a UUID before validation on create
#   - Add a `to_param` method that returns the UUID (for URL generation)
#   - Add a `find_by_public_id` class method for looking up records
#   - Add a `public_id` alias for the uuid field
module Identifiable
  extend ActiveSupport::Concern

  included do
    # Generate UUID before validation to ensure it's present for validation
    before_validation :generate_uuid, on: :create

    # Validate UUID presence and uniqueness
    validates :uuid, presence: true, uniqueness: true
  end

  # Override to_param to use UUID in URLs instead of ID
  # This makes all URLs use UUID: /locations/550e8400-e29b-41d4-a716-446655440000
  def to_param
    uuid
  end

  # Alias for clearer semantics when accessing the public identifier
  def public_id
    uuid
  end

  class_methods do
    # Find a record by its public-facing UUID
    # Falls back to ID lookup for backwards compatibility during migration
    #
    # @param id_or_uuid [String, Integer] The UUID or ID to search for
    # @return [ApplicationRecord, nil] The found record or nil
    def find_by_public_id(id_or_uuid)
      return nil if id_or_uuid.blank?

      # Try UUID first (36 chars with dashes, 32 without)
      if uuid_format?(id_or_uuid)
        find_by(uuid: id_or_uuid)
      else
        # Fall back to ID for backwards compatibility
        find_by(id: id_or_uuid)
      end
    end

    # Find a record by its public-facing UUID, raising an error if not found
    #
    # @param id_or_uuid [String, Integer] The UUID or ID to search for
    # @return [ApplicationRecord] The found record
    # @raise [ActiveRecord::RecordNotFound] If the record is not found
    def find_by_public_id!(id_or_uuid)
      find_by_public_id(id_or_uuid) || raise(ActiveRecord::RecordNotFound, "Couldn't find #{name} with UUID or ID '#{id_or_uuid}'")
    end

    private

    # Check if the given string looks like a UUID
    def uuid_format?(str)
      return false unless str.is_a?(String)

      # Standard UUID format: 8-4-4-4-12 hex chars with dashes
      # or 32 hex chars without dashes
      str.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i) ||
        str.match?(/\A[0-9a-f]{32}\z/i)
    end
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
