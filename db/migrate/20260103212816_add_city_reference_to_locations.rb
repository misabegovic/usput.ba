class AddCityReferenceToLocations < ActiveRecord::Migration[8.1]
  def change
    add_reference :locations, :city, null: true, foreign_key: true
  end
end
