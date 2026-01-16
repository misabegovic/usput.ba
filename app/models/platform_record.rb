# frozen_string_literal: true

# Abstract base class for all Platform-related models.
# These models connect to the platform database which has pgvector
# enabled for semantic search capabilities.
#
# Tables in platform database:
# - platform_conversations
# - platform_statistics
# - knowledge_summaries
# - knowledge_clusters
# - cluster_memberships
# - platform_audit_logs
# - prepared_prompts
#
class PlatformRecord < ApplicationRecord
  self.abstract_class = true

  # Check if the platform database is configured
  def self.platform_database_configured?
    return @platform_database_configured if defined?(@platform_database_configured)

    @platform_database_configured = begin
      config = Rails.application.config.database_configuration[Rails.env]
      platform_config = config&.dig("platform") || config&.dig(:platform)
      platform_config.present? && (
        platform_config["url"].present? ||
        platform_config["database"].present? ||
        platform_config[:url].present? ||
        platform_config[:database].present?
      )
    rescue StandardError
      false
    end
  end

  # Check if the platform database is available (connected and has tables)
  def self.platform_database_available?
    return false unless platform_database_configured?
    return @platform_database_available if defined?(@platform_database_available)

    @platform_database_available = begin
      connection.execute("SELECT 1")
      true
    rescue StandardError
      false
    end
  end

  # Safe column_names that doesn't raise if table doesn't exist
  def self.safe_column_names
    return [] unless platform_database_configured?

    column_names
  rescue ActiveRecord::StatementInvalid, PG::UndefinedTable, StandardError
    []
  end

  # Only connect to platform database if it's configured
  # This allows the app to run without the platform database for web-only deployments
  if platform_database_configured?
    connects_to database: { writing: :platform, reading: :platform }
  end
end
