# frozen_string_literal: true

# Add seasons array to locations for seasonal recommendations.
# Uses JSONB array like experiences (e.g., ["spring", "summer"]).
# Empty array means year-round availability.
class AddSeasonsToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :seasons, :jsonb, default: [], null: false
    add_index :locations, :seasons, using: :gin
  end
end
