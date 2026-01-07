# Flipper configuration for feature flags
# No web UI - manage flags via Rails console only
#
# Usage in Rails console:
#   Flipper.enable(:admin_dashboard)   # Enable flag globally
#   Flipper.disable(:admin_dashboard)  # Disable flag globally
#   Flipper.enabled?(:admin_dashboard) # Check if flag is enabled
#
# Note: :admin_dashboard flag is disabled by default.
# Enable it via console to allow admin dashboard access.

require "flipper"
require "flipper/adapters/active_record"

Flipper.configure do |config|
  config.adapter do
    Flipper::Adapters::ActiveRecord.new
  end
end
