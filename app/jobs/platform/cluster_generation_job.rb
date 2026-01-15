# frozen_string_literal: true

module Platform
  class ClusterGenerationJob < ApplicationJob
    queue_as :default

    # Daily job - don't retry too aggressively
    retry_on StandardError, wait: 30.minutes, attempts: 2

    def perform(regenerate: false)
      Rails.logger.info "[Platform::ClusterGenerationJob] Starting cluster generation"

      # Generate or refresh clusters
      if regenerate || KnowledgeCluster.count.zero?
        generate_clusters
      end

      # Always update cluster memberships
      assign_memberships

      Rails.logger.info "[Platform::ClusterGenerationJob] Completed. #{KnowledgeCluster.count} clusters, #{ClusterMembership.count} memberships"
    end

    private

    def generate_clusters
      Rails.logger.info "[Platform::ClusterGenerationJob] Generating clusters..."
      Platform::Knowledge::LayerTwo.generate_clusters
    end

    def assign_memberships
      Rails.logger.info "[Platform::ClusterGenerationJob] Assigning memberships..."
      Platform::Knowledge::LayerTwo.assign_to_clusters
    end
  end
end
