class CreateLocationExperienceTypes < ActiveRecord::Migration[8.1]
  def change
    # Join table between locations and experience_types
    # Replaces the JSON suitable_experiences field
    create_table :location_experience_types do |t|
      t.references :location, null: false, foreign_key: true
      t.references :experience_type, null: false, foreign_key: true

      t.timestamps
    end

    add_index :location_experience_types,
              [:location_id, :experience_type_id],
              unique: true,
              name: "idx_location_experience_types_uniqueness"
  end
end
