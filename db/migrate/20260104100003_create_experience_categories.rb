class CreateExperienceCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :experience_categories do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :icon
      t.integer :default_duration, default: 180
      t.integer :position, default: 0
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :experience_categories, :key, unique: true
    add_index :experience_categories, :active
    add_index :experience_categories, :position
  end
end
