class CreateExperiences < ActiveRecord::Migration[8.1]
  def change
    create_table :experiences do |t|
      t.string :title, null: false
      t.text :description
      t.integer :estimated_duration # u minutama

      t.timestamps
    end

    add_index :experiences, :title
  end
end
