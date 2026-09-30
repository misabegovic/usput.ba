class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :password_digest, :encrypted_password

    change_table :users, bulk: true do |t|
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email

      t.string :session_token
      t.datetime :blocked_at
    end

    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token, unique: true

    # Devise stores emails already lower-cased, so a plain unique index serves
    # both the lookup at sign-in and the uniqueness rule.
    remove_index :users, name: "index_users_on_lower_email", column: :email, unique: true, expression: "lower((email)::text)"
    add_index :users, :email, unique: true
    change_column_null :users, :email, false
  end
end
