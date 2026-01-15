# frozen_string_literal: true

class CreatePlatformAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_audit_logs do |t|
      t.string :action, null: false
      t.string :record_type
      t.bigint :record_id
      t.jsonb :change_data, default: {}
      t.string :triggered_by, null: false
      t.uuid :conversation_id

      t.timestamps

      t.index [:record_type, :record_id]
      t.index :action
      t.index :triggered_by
      t.index :conversation_id
    end
  end
end
