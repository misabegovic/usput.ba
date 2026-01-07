class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.jsonb :travel_profile_data, default: {}

      t.timestamps
    end

    add_index :users, :username, unique: true
  end
end
