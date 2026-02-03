class DropPlatformConversations < ActiveRecord::Migration[8.1]
  def up
    drop_table :platform_conversations, if_exists: true
  end

  def down
    create_table :platform_conversations, id: :uuid do |t|
      t.jsonb :messages, default: [], null: false
      t.jsonb :context, default: {}
      t.string :status, default: "active"
      t.timestamps
    end

    add_index :platform_conversations, :status
  end
end
