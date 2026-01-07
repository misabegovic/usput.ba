class CreatePlanExperiences < ActiveRecord::Migration[8.1]
  def change
    create_table :plan_experiences do |t|
      t.references :plan, null: false, foreign_key: true
      t.references :experience, null: false, foreign_key: true
      t.integer :day_number, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :plan_experiences, [:plan_id, :day_number]
    add_index :plan_experiences, [:plan_id, :day_number, :position]
    add_index :plan_experiences, [:plan_id, :experience_id], unique: true
  end
end
