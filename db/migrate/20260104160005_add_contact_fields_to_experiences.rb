class AddContactFieldsToExperiences < ActiveRecord::Migration[8.1]
  def change
    add_column :experiences, :contact_name, :string
    add_column :experiences, :contact_email, :string
    add_column :experiences, :contact_phone, :string
    add_column :experiences, :contact_website, :string
  end
end
