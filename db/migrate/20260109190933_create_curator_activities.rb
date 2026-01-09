class CreateCuratorActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :curator_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.references :recordable, polymorphic: true
      t.jsonb :metadata, default: {}
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :curator_activities, [:user_id, :created_at]
    add_index :curator_activities, [:action, :created_at]
    add_index :curator_activities, :created_at

    # Spam protection fields for users
    add_column :users, :spam_blocked_at, :datetime
    add_column :users, :spam_blocked_until, :datetime
    add_column :users, :spam_block_reason, :string
    add_column :users, :activity_count_today, :integer, default: 0
    add_column :users, :activity_count_reset_at, :datetime

    # Photo suggestions table
    create_table :photo_suggestions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.string :photo_url
      t.text :description
      t.integer :status, default: 0 # 0=pending, 1=approved, 2=rejected
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :admin_notes

      t.timestamps
    end

    add_index :photo_suggestions, [:location_id, :status]
    add_index :photo_suggestions, [:user_id, :status]
  end
end
