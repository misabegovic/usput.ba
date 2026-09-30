class AddEmailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email, :string
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
  end
end
