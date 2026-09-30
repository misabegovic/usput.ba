class DropCuratorApplications < ActiveRecord::Migration[8.1]
  def change
    drop_table :curator_applications do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :uuid, limit: 36, null: false
      t.integer :status, default: 0, null: false
      t.text :motivation, null: false
      t.text :experience
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :admin_notes
      t.timestamps
      t.index :status
      t.index %i[user_id status]
      t.index :user_id
      t.index :uuid, unique: true
    end
  end
end
