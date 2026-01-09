class AddContributorsToContentChanges < ActiveRecord::Migration[8.1]
  def change
    # Track individual contributions to a content change proposal
    create_table :content_change_contributions do |t|
      t.references :content_change, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :proposed_data, default: {}
      t.text :notes
      t.timestamps
    end

    add_index :content_change_contributions, [:content_change_id, :user_id], unique: true, name: "idx_contributions_unique_user_per_change"

    # Curator reviews/comments on proposals
    create_table :curator_reviews do |t|
      t.references :content_change, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :comment, null: false
      t.integer :recommendation, default: 0 # 0=neutral, 1=approve, 2=reject
      t.timestamps
    end

    add_index :curator_reviews, [:content_change_id, :created_at]

    # Add unique constraint: only one pending proposal per resource
    # (for updates/deletes - changeable_type + changeable_id + status=pending)
    add_index :content_changes, [:changeable_type, :changeable_id],
      unique: true,
      where: "status = 0 AND changeable_id IS NOT NULL",
      name: "idx_unique_pending_proposal_per_resource"

    # For creates: unique by changeable_class + proposed name/title + status=pending
    # This is harder to enforce at DB level, will handle in model
  end
end
