class CreateExperienceTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :experience_types do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :icon
      t.string :color
      t.integer :position, default: 0
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :experience_types, :key, unique: true
    add_index :experience_types, :active
    add_index :experience_types, :position
  end
end
