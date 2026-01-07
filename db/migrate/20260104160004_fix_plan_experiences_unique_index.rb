class FixPlanExperiencesUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    # Remove the old unique index that prevents same experience on multiple days
    remove_index :plan_experiences, [:plan_id, :experience_id],
                 name: "index_plan_experiences_on_plan_id_and_experience_id",
                 if_exists: true

    # Add a new unique index that includes day_number
    # This allows the same experience to appear on different days of the plan
    add_index :plan_experiences, [:plan_id, :experience_id, :day_number],
              unique: true,
              name: "index_plan_experiences_unique_per_day"
  end
end
