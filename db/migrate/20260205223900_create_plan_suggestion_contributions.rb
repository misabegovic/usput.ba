# frozen_string_literal: true

class CreatePlanSuggestionContributions < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_suggestion_contributions do |t|
      t.references :plan_suggestion, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :notes

      # Same typed proposed fields as PlanSuggestion
      # Only non-nil fields = fields that this curator is changing
      t.string :proposed_title
      t.text :proposed_notes
      t.string :proposed_city_name
      t.date :proposed_start_date
      t.date :proposed_end_date
      t.integer :proposed_visibility
      t.jsonb :proposed_preferences
      t.jsonb :proposed_experience_days

      t.timestamps
    end

    add_index :plan_suggestion_contributions,
              [:plan_suggestion_id, :user_id],
              unique: true,
              name: "idx_plan_suggestion_contrib_unique_user"
  end
end
