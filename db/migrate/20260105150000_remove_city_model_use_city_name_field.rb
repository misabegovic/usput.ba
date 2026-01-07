class RemoveCityModelUseCityNameField < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Add city_name to plans
    add_column :plans, :city_name, :string

    # Step 2: Add city_name to ai_generations
    add_column :ai_generations, :city_name, :string

    # Step 3: Add city_name to browses
    add_column :browses, :city_name, :string

    # Step 4: Backfill city_name from cities table
    execute <<-SQL
      UPDATE plans
      SET city_name = (
        SELECT CONCAT(cities.name, ', ', COALESCE(cities.country_name, cities.country_code))
        FROM cities
        WHERE cities.id = plans.city_id
      )
      WHERE city_id IS NOT NULL
    SQL

    execute <<-SQL
      UPDATE ai_generations
      SET city_name = (
        SELECT CONCAT(cities.name, ', ', COALESCE(cities.country_name, cities.country_code))
        FROM cities
        WHERE cities.id = ai_generations.city_id
      )
      WHERE city_id IS NOT NULL
    SQL

    execute <<-SQL
      UPDATE browses
      SET city_name = (
        SELECT cities.name
        FROM cities
        WHERE cities.id = browses.city_id
      )
      WHERE city_id IS NOT NULL
    SQL

    # Also update locations.city field from the city association if not already set
    execute <<-SQL
      UPDATE locations
      SET city = (
        SELECT cities.name
        FROM cities
        WHERE cities.id = locations.city_id
      )
      WHERE city_id IS NOT NULL AND (city IS NULL OR city = '')
    SQL

    # Step 5: Remove foreign key constraints
    remove_foreign_key :plans, :cities
    remove_foreign_key :ai_generations, :cities
    remove_foreign_key :locations, :cities
    remove_foreign_key :browses, :cities

    # Step 6: Remove city_id columns
    remove_index :plans, :city_id
    remove_column :plans, :city_id

    remove_index :ai_generations, :city_id
    remove_index :ai_generations, name: :index_ai_generations_on_city_id_and_generation_type, if_exists: true
    remove_column :ai_generations, :city_id

    remove_index :locations, :city_id
    remove_column :locations, :city_id

    remove_index :browses, :city_id
    remove_column :browses, :city_id

    # Step 7: Drop the cities table
    drop_table :cities

    # Step 8: Add indexes for city_name
    add_index :plans, :city_name
    add_index :ai_generations, :city_name
    add_index :browses, :city_name
  end

  def down
    # Recreate cities table
    create_table :cities do |t|
      t.string :name, null: false
      t.string :country_code, limit: 2, null: false
      t.string :country_name
      t.string :region
      t.decimal :lat, precision: 10, scale: 6, null: false
      t.decimal :lng, precision: 10, scale: 6, null: false
      t.integer :population, default: 0
      t.string :timezone

      t.timestamps
    end

    add_index :cities, :name
    add_index :cities, :country_code
    add_index :cities, [:name, :country_code]
    add_index :cities, :population
    add_index :cities, [:lat, :lng]

    # Re-add city_id to tables
    add_reference :plans, :city, null: true, foreign_key: true
    add_reference :ai_generations, :city, null: true, foreign_key: true
    add_reference :locations, :city, null: true, foreign_key: true
    add_reference :browses, :city, null: true, foreign_key: true

    # Remove city_name columns
    remove_index :plans, :city_name, if_exists: true
    remove_index :ai_generations, :city_name, if_exists: true
    remove_index :browses, :city_name, if_exists: true
    remove_column :plans, :city_name
    remove_column :ai_generations, :city_name
    remove_column :browses, :city_name
  end
end
