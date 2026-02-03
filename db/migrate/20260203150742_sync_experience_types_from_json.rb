class SyncExperienceTypesFromJson < ActiveRecord::Migration[8.1]
  def up
    # This migration ensures all existing locations have their experience types
    # properly synced from the suitable_experiences JSON field to the
    # location_experience_types relational table.
    #
    # This is needed after refactoring from JSON-only to relational + JSON cache.

    say "Syncing experience types from JSON to relational data..."

    # Counter for reporting
    synced_count = 0
    created_relations = 0
    skipped_locations = 0

    # Process all locations in batches (memory efficient)
    Location.find_each do |location|
      # Skip if no suitable_experiences JSON data
      suitable_experiences = location.read_attribute(:suitable_experiences)
      if suitable_experiences.blank?
        skipped_locations += 1
        next
      end

      synced_count += 1

      # Convert to array if needed
      keys = Array(suitable_experiences).map(&:to_s).map(&:downcase).uniq

      # Process each experience type key
      keys.each do |key|
        # Find the experience type
        exp_type = ExperienceType.find_by("LOWER(key) = ?", key)

        unless exp_type
          say "  Warning: ExperienceType '#{key}' not found for location '#{location.name}' (ID: #{location.id})", :yellow
          next
        end

        # Create or update the relation
        relation = LocationExperienceType.find_or_initialize_by(
          location_id: location.id,
          experience_type_id: exp_type.id
        )

        if relation.new_record?
          relation.save!
          created_relations += 1
        end
      end
    end

    say "Sync complete!", :green
    say "  Locations processed: #{synced_count}"
    say "  Relations created: #{created_relations}"
    say "  Locations skipped (no data): #{skipped_locations}"
  end

  def down
    # No rollback needed - data remains consistent
    # The JSON field still exists and contains the same data
    say "No rollback needed - relational data is additive", :yellow
  end
end
