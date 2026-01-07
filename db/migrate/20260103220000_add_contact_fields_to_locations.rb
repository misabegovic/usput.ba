class AddContactFieldsToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :location_type, :integer, default: 0
    add_column :locations, :phone, :string
    add_column :locations, :email, :string
    add_column :locations, :website, :string
    add_column :locations, :social_links, :jsonb, default: {}

    add_index :locations, :location_type
  end
end
