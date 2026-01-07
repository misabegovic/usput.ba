class RemoveDuplicateLocationsAndAddCoordinatesIndex < ActiveRecord::Migration[8.0]
  def up
    # First, remove duplicate locations (keep the oldest one based on id)
    # Find duplicates based on lat/lng combination
    duplicates_sql = <<-SQL
      DELETE FROM locations
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM locations
        WHERE lat IS NOT NULL AND lng IS NOT NULL
        GROUP BY lat, lng
      )
      AND lat IS NOT NULL
      AND lng IS NOT NULL
    SQL

    execute(duplicates_sql)

    # Add unique index on lat/lng combination (only for non-null values)
    add_index :locations, [:lat, :lng], unique: true, where: "lat IS NOT NULL AND lng IS NOT NULL", name: "index_locations_on_coordinates_unique"
  end

  def down
    remove_index :locations, name: "index_locations_on_coordinates_unique", if_exists: true
  end
end
