# frozen_string_literal: true

class CreateExperienceSuggestionContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :experience_suggestion_contributions do |t|
      t.references :experience_suggestion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :notes

      # Same typed proposed fields as ExperienceSuggestion
      # Only non-nil fields = fields that this curator is changing
      t.string :proposed_title
      t.text :proposed_description
      t.bigint :proposed_experience_category_id
      t.integer :proposed_estimated_duration
      t.string :proposed_contact_name
      t.string :proposed_contact_email
      t.string :proposed_contact_phone
      t.string :proposed_contact_website
      t.jsonb :proposed_seasons
      t.jsonb :proposed_video_urls
      t.jsonb :proposed_location_uuids

      t.timestamps
    end

    add_index :experience_suggestion_contributions,
              [:experience_suggestion_id, :user_id],
              unique: true,
              name: "idx_exp_suggestion_contrib_unique_user"
  end
end
