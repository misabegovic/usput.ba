class CreatePlanVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :plan_visits do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end

    add_index :plan_visits, [ :user_id, :plan_id, :location_id ], unique: true
  end
end
