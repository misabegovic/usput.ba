# frozen_string_literal: true

class CreateExperienceSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :experience_suggestions do |t|
      t.references :experience, foreign_key: true  # nil for create_resource
      t.references :user, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.integer :status, default: 0, null: false
      t.integer :change_type, default: 0, null: false
      t.integer :origin, default: 0, null: false
      t.string :ai_service
      t.datetime :reviewed_at
      t.text :admin_notes

      # Typed proposed fields matching Experience attributes
      t.string :proposed_title
      t.text :proposed_description
      t.bigint :proposed_experience_category_id
      t.integer :proposed_estimated_duration
      t.string :proposed_contact_name
      t.string :proposed_contact_email
      t.string :proposed_contact_phone
      t.string :proposed_contact_website
      t.jsonb :proposed_seasons, default: []
      t.jsonb :proposed_video_urls, default: []
      t.jsonb :proposed_location_uuids, default: []

      t.timestamps
    end

    # One pending suggestion per experience
    add_index :experience_suggestions, :experience_id,
              unique: true,
              where: "status = 0 AND experience_id IS NOT NULL",
              name: "idx_one_pending_per_experience"
  end
end
