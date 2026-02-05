# frozen_string_literal: true

class CreateLocationSuggestionContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :location_suggestion_contributions do |t|
      t.references :location_suggestion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :notes

      # Same typed proposed fields as LocationSuggestion
      # Only non-nil fields = fields that this curator is changing
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
      t.jsonb :proposed_video_urls
      t.jsonb :proposed_social_links
      t.jsonb :proposed_tags
      t.jsonb :proposed_category_ids
      t.jsonb :proposed_experience_type_ids

      t.timestamps
    end

    add_index :location_suggestion_contributions,
              [:location_suggestion_id, :user_id],
              unique: true,
              name: "idx_loc_suggestion_contrib_unique_user"
  end
end
