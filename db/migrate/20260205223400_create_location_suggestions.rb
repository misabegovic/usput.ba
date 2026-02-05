# frozen_string_literal: true

class CreateLocationSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :location_suggestions do |t|
      t.references :location, foreign_key: true  # nil for create_resource
      t.references :user, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.integer :status, default: 0, null: false
      t.integer :change_type, default: 0, null: false
      t.integer :origin, default: 0, null: false
      t.string :ai_service
      t.datetime :reviewed_at
      t.text :admin_notes

      # Typed proposed fields matching Location attributes
      t.string :proposed_name
      t.string :proposed_city
      t.text :proposed_description
      t.text :proposed_historical_context
      t.decimal :proposed_lat, precision: 10, scale: 6
      t.decimal :proposed_lng, precision: 10, scale: 6
      t.integer :proposed_budget
      t.string :proposed_phone
      t.string :proposed_email
      t.string :proposed_website
      t.jsonb :proposed_video_urls, default: []
      t.jsonb :proposed_social_links, default: {}
      t.jsonb :proposed_tags, default: []
      t.jsonb :proposed_category_ids, default: []
      t.jsonb :proposed_experience_type_ids, default: []

      t.timestamps
    end

    # One pending suggestion per location
    add_index :location_suggestions, :location_id,
              unique: true,
              where: "status = 0 AND location_id IS NOT NULL",
              name: "idx_one_pending_per_location"
  end
end
