# frozen_string_literal: true

require "test_helper"

class KnowledgeClusterTest < ActiveSupport::TestCase
  setup do
    KnowledgeCluster.delete_all
    ClusterMembership.delete_all
  end

  test "validates slug presence" do
    cluster = KnowledgeCluster.new(name: "Test Cluster")
    assert_not cluster.valid?
    assert cluster.errors[:slug].any?
  end

  test "validates name presence" do
    cluster = KnowledgeCluster.new(slug: "test-cluster")
    assert_not cluster.valid?
    assert cluster.errors[:name].any?
  end

  test "validates slug uniqueness" do
    KnowledgeCluster.create!(slug: "ottoman", name: "Ottoman Heritage")

    duplicate = KnowledgeCluster.new(slug: "ottoman", name: "Another Ottoman")
    assert_not duplicate.valid?
    assert duplicate.errors[:slug].any?
  end

  test "creates valid cluster" do
    cluster = KnowledgeCluster.create!(
      slug: "ottoman-heritage",
      name: "Osmansko nasljeđe",
      summary: "Historical Ottoman sites",
      stats: { keywords: %w[džamija most] },
      representative_ids: [1, 2, 3],
      member_count: 10
    )

    assert cluster.persisted?
    assert_equal "ottoman-heritage", cluster.slug
    assert_equal "Osmansko nasljeđe", cluster.name
    assert_equal 10, cluster.member_count
  end

  test "by_member_count scope orders by member_count descending" do
    small = KnowledgeCluster.create!(slug: "small", name: "Small", member_count: 5)
    large = KnowledgeCluster.create!(slug: "large", name: "Large", member_count: 100)
    medium = KnowledgeCluster.create!(slug: "medium", name: "Medium", member_count: 50)

    result = KnowledgeCluster.by_member_count

    assert_equal large, result.first
    assert_equal small, result.last
  end

  test "refresh_member_count! updates from memberships" do
    cluster = KnowledgeCluster.create!(slug: "test", name: "Test", member_count: 0)

    # Create a test location
    location = Location.create!(name: "Test", city: "Test", lat: 43.0, lng: 18.0)

    # Add membership
    ClusterMembership.create!(
      knowledge_cluster: cluster,
      record_type: "Location",
      record_id: location.id
    )

    cluster.refresh_member_count!

    assert_equal 1, cluster.reload.member_count
  end

  test "to_short_format returns formatted string" do
    cluster = KnowledgeCluster.create!(
      slug: "test",
      name: "Test Cluster",
      member_count: 25
    )

    result = cluster.to_short_format

    assert result.include?("Test Cluster")
    assert result.include?("test")
    assert result.include?("25 members")
  end

  test "to_cli_format returns detailed format" do
    cluster = KnowledgeCluster.create!(
      slug: "ottoman",
      name: "Ottoman Heritage",
      summary: "Historical sites from Ottoman period",
      stats: { keywords: ["džamija", "most"] },
      member_count: 45
    )

    result = cluster.to_cli_format

    assert result.include?("Ottoman Heritage")
    assert result.include?("ottoman")
    assert result.include?("45")
    assert result.include?("Historical sites")
  end

  test "semantic_search_available? checks for embedding column" do
    # In test environment without pgvector, should return false
    # The column won't exist since we couldn't enable pgvector
    available = KnowledgeCluster.semantic_search_available?

    assert_not available unless KnowledgeCluster.column_names.include?("embedding")
  end
end
