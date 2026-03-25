class AddAccessibilityToLocationsAndBrowses < ActiveRecord::Migration[8.1]
  def change
    # JSONB column for structured accessibility data on locations
    # Schema: { wheelchair_access: "full"|"partial"|"none"|"unknown",
    #           wheelchair_parking: bool, wheelchair_toilet: bool,
    #           flat_terrain: bool, elevator: bool, ramp: bool,
    #           notes: "string" }
    add_column :locations, :accessibility, :jsonb, default: {}, null: false

    # Denormalized boolean on browses for fast filtering
    # true when wheelchair_access is "full" or "partial"
    add_column :browses, :wheelchair_accessible, :boolean, default: false, null: false
    add_index :browses, :wheelchair_accessible
  end
end
