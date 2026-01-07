class CreateCuratorApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :curator_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.text :motivation, null: false
      t.text :experience
      t.integer :status, default: 0, null: false
      t.text :admin_notes
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :curator_applications, :status
    add_index :curator_applications, [ :user_id, :status ]
  end
end
