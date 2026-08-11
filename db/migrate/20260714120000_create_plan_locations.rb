class CreatePlanLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :plan_locations do |t|
      t.references :plan, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :day_number, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :plan_locations, [ :plan_id, :day_number, :position ]
    add_index :plan_locations, [ :plan_id, :day_number ]
    add_index :plan_locations, [ :plan_id, :location_id, :day_number ],
              unique: true, name: "index_plan_locations_unique_per_day"
  end
end
