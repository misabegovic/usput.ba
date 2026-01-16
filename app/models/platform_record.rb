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

  connects_to database: { writing: :platform, reading: :platform }
end
