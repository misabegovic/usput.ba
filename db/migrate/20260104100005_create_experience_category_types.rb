class CreateExperienceCategoryTypes < ActiveRecord::Migration[8.1]
  def change
    # Join table between experience_categories and experience_types
    create_table :experience_category_types do |t|
      t.references :experience_category, null: false, foreign_key: true
      t.references :experience_type, null: false, foreign_key: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :experience_category_types,
              [:experience_category_id, :experience_type_id],
              unique: true,
              name: "idx_category_types_uniqueness"
  end
end
