class DropSessions < ActiveRecord::Migration[8.1]
  def change
    drop_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_seen_at
      t.timestamps
    end
  end
end
