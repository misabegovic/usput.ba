class DropGeoapifyCategories < ActiveRecord::Migration[8.1]
  def up
    drop_table :geoapify_categories, if_exists: true
  end

  def down
    create_table :geoapify_categories do |t|
      t.string :api_category, null: false
      t.string :mapped_type
      t.string :display_name
      t.boolean :active, default: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :geoapify_categories, :api_category, unique: true
    add_index :geoapify_categories, :active
  end
end
