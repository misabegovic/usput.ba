class CreateExperienceLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :experience_locations do |t|
      t.references :experience, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :experience_locations, [:experience_id, :position]
    add_index :experience_locations, [:experience_id, :location_id], unique: true
  end
end
