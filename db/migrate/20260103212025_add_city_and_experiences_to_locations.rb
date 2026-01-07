class AddCityAndExperiencesToLocations < ActiveRecord::Migration[8.1]
  def change
    # Add city field
    add_column :locations, :city, :string

    # Convert tags from string to JSON array
    remove_column :locations, :tags, :string
    add_column :locations, :tags, :jsonb, default: []

    # Add suitable_experiences as JSON array
    add_column :locations, :suitable_experiences, :jsonb, default: []

    # Add index on city for filtering
    add_index :locations, :city
  end
end
