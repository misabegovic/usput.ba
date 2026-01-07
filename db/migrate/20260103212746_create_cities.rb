class CreateCities < ActiveRecord::Migration[8.1]
  def change
    create_table :cities do |t|
      t.string :name, null: false
      t.string :country_code, null: false, limit: 2
      t.string :country_name
      t.string :region
      t.decimal :lat, precision: 10, scale: 6, null: false
      t.decimal :lng, precision: 10, scale: 6, null: false
      t.integer :population, default: 0
      t.string :timezone

      t.timestamps
    end

    # Indeksi za pretraživanje
    add_index :cities, :name
    add_index :cities, :country_code
    add_index :cities, [ :name, :country_code ]
    add_index :cities, :population
    add_index :cities, [ :lat, :lng ]
  end
end
