# frozen_string_literal: true

require "test_helper"

class Platform::ClusterGenerationJobTest < ActiveSupport::TestCase
  setup do
    KnowledgeCluster.delete_all
    ClusterMembership.delete_all

    # Create test locations
    @location = Location.create!(
      name: "Stari Most",
      city: "Mostar",
      lat: 43.3,
      lng: 17.8,
      description: "Poznati most iz osmanskog perioda."
    )
  end

  test "perform generates clusters when none exist" do
    assert_equal 0, KnowledgeCluster.count

    Platform::ClusterGenerationJob.perform_now

    assert KnowledgeCluster.count > 0
  end

  test "perform assigns memberships to clusters" do
    # Pre-create a cluster with matching keywords
    cluster = KnowledgeCluster.create!(
      slug: "ottoman-heritage",
      name: "Osmansko nasljeđe",
      stats: { keywords: %w[most osmanski] }
    )

    Platform::ClusterGenerationJob.perform_now

    cluster.reload
    assert cluster.member_count > 0
  end

  test "perform with regenerate flag recreates clusters" do
    # Create existing cluster
    old_cluster = KnowledgeCluster.create!(
      slug: "old-cluster",
      name: "Old Cluster"
    )

    Platform::ClusterGenerationJob.perform_now(regenerate: true)

    # Should have default clusters now
    assert KnowledgeCluster.exists?(slug: "ottoman-heritage")
  end

  test "perform handles missing data gracefully" do
    Location.delete_all

    assert_nothing_raised do
      Platform::ClusterGenerationJob.perform_now
    end
  end

  test "perform updates member_count on clusters" do
    cluster = KnowledgeCluster.create!(
      slug: "ottoman-heritage",
      name: "Osmansko nasljeđe",
      stats: { keywords: %w[most] },
      member_count: 0
    )

    Platform::ClusterGenerationJob.perform_now

    cluster.reload
    # member_count should be updated based on actual memberships
    assert_equal cluster.cluster_memberships.count, cluster.member_count
  end
end
