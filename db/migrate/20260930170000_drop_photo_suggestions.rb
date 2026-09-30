class DropPhotoSuggestions < ActiveRecord::Migration[8.1]
  def change
    drop_table :photo_suggestions do |t|
      t.references :location, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true, index: false
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.text :description
      t.string :photo_url
      t.integer :status, default: 0
      t.datetime :reviewed_at
      t.text :admin_notes
      t.timestamps
      t.index %i[location_id status]
      t.index :location_id
      t.index %i[user_id status]
      t.index :user_id
    end
  end
end
