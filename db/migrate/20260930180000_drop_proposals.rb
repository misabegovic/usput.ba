class DropProposals < ActiveRecord::Migration[8.1]
  def change
    drop_table :curator_reviews do |t|
      t.references :content_change, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :comment, null: false
      t.integer :recommendation, default: 0
      t.timestamps
      t.index %i[content_change_id created_at]
    end

    drop_table :content_change_contributions do |t|
      t.references :content_change, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :proposed_data, default: {}
      t.text :notes
      t.timestamps
      t.index %i[content_change_id user_id], unique: true, name: "idx_contributions_unique_user_per_change"
    end

    drop_table :content_changes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.integer :change_type, default: 0, null: false
      t.string :changeable_class
      t.bigint :changeable_id
      t.string :changeable_type
      t.jsonb :original_data, default: {}
      t.jsonb :proposed_data, default: {}
      t.datetime :reviewed_at
      t.integer :status, default: 0, null: false
      t.text :admin_notes
      t.timestamps
      t.index :change_type
      t.index :status
      t.index %i[user_id status]
      t.index %i[changeable_type changeable_id], name: "index_content_changes_on_changeable"
      t.index %i[changeable_type changeable_id status], name: "idx_content_changes_on_changeable_and_status"
      t.index %i[changeable_type changeable_id], unique: true, where: "((status = 0) AND (changeable_id IS NOT NULL))",
        name: "idx_unique_pending_proposal_per_resource"
    end
  end
end
