# The curator dashboard's activity trail and spam counter, and Flipper, whose
# only flag the dashboard read. Decisions are recorded in Rails Event Store.
class DropCuratorDashboardTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :curator_activities
    drop_table :flipper_gates
    drop_table :flipper_features
    change_table :users, bulk: true do |t|
      t.remove :activity_count_today, :activity_count_reset_at, :spam_blocked_at, :spam_blocked_until, :spam_block_reason
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
