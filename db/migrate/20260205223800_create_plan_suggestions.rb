# frozen_string_literal: true

class CreatePlanSuggestions < ActiveRecord::Migration[8.0]
  def change
    create_table :plan_suggestions do |t|
      t.references :plan, foreign_key: true  # nil for create_resource
      t.references :user, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }

      t.integer :status, default: 0, null: false
      t.integer :change_type, default: 0, null: false
      t.integer :origin, default: 0, null: false
      t.string :ai_service
      t.datetime :reviewed_at
      t.text :admin_notes

      # Typed proposed fields matching Plan attributes
      t.string :proposed_title
      t.text :proposed_notes
      t.string :proposed_city_name
      t.date :proposed_start_date
      t.date :proposed_end_date
      t.integer :proposed_visibility
      t.jsonb :proposed_preferences, default: {}
      t.jsonb :proposed_experience_days, default: {}

      t.timestamps
    end

    # One pending suggestion per plan
    add_index :plan_suggestions, :plan_id,
              unique: true,
              where: "status = 0 AND plan_id IS NOT NULL",
              name: "idx_one_pending_per_plan"
  end
end
