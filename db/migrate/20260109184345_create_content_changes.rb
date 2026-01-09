class CreateContentChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :content_changes do |t|
      # For edits/deletes: references existing record
      # For creates: null until approved (then points to new record)
      t.references :changeable, polymorphic: true, null: true

      # Who proposed this change
      t.references :user, null: false, foreign_key: true

      # Type: create, update, delete
      t.integer :change_type, null: false, default: 0

      # Status: pending, approved, rejected
      t.integer :status, null: false, default: 0

      # The proposed new data (for create/update)
      t.jsonb :proposed_data, default: {}

      # Original data before change (for update, useful for diff)
      t.jsonb :original_data, default: {}

      # For creates: which model type to create
      t.string :changeable_class

      # Admin review fields
      t.text :admin_notes
      t.references :reviewed_by, foreign_key: { to_table: :users }, null: true
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :content_changes, :status
    add_index :content_changes, :change_type
    add_index :content_changes, [:user_id, :status]
    add_index :content_changes, [:changeable_type, :changeable_id, :status], name: "idx_content_changes_on_changeable_and_status"
  end
end
