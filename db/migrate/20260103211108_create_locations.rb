class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.decimal :lat, precision: 10, scale: 6
      t.decimal :lng, precision: 10, scale: 6
      t.string :name, null: false
      t.text :description
      t.text :historical_context
      t.string :video_url
      t.string :tags
      t.integer :budget, default: 0

      t.timestamps
    end

    add_index :locations, :name
    add_index :locations, :budget
  end
end
