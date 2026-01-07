class AddAdminDashboardFeatureFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.enable(:admin_dashboard)
  end

  def down
    Flipper.disable(:admin_dashboard)
  end
end
