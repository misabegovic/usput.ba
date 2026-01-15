# frozen_string_literal: true

require "test_helper"

class Platform::Knowledge::LayerTwoTest < ActiveSupport::TestCase
  setup do
    KnowledgeCluster.delete_all
    ClusterMembership.delete_all

    # Create test locations with descriptions containing keywords
    @location1 = Location.create!(
      name: "Stari Most",
      city: "Mostar",
      lat: 43.3,
      lng: 17.8,
      description: "Poznati most iz osmanskog perioda, simbol grada Mostara."
    )

    @location2 = Location.create!(
      name: "Džamija",
      city: "Sarajevo",
      lat: 43.8,
      lng: 18.4,
      description: "Historijska džamija iz osmanskog doba."
    )

    @location3 = Location.create!(
      name: "Restoran Ćevabdžinica",
      city: "Sarajevo",
      lat: 43.85,
      lng: 18.42,
      description: "Tradicionalni restoran sa domaćom kuhinjom i ćevapima."
    )
  end

  test "get_cluster returns cluster by slug" do
    cluster = KnowledgeCluster.create!(
      slug: "ottoman-heritage",
      name: "Osmansko nasljeđe"
    )

    result = Platform::Knowledge::LayerTwo.get_cluster("ottoman-heritage")

    assert_equal cluster, result
  end

  test "get_cluster returns nil for unknown slug" do
    result = Platform::Knowledge::LayerTwo.get_cluster("nonexistent")

    assert_nil result
  end

  test "list_clusters returns all clusters ordered by member_count" do
    KnowledgeCluster.create!(slug: "small", name: "Small", member_count: 5)
    KnowledgeCluster.create!(slug: "large", name: "Large", member_count: 100)

    result = Platform::Knowledge::LayerTwo.list_clusters

    assert_equal 2, result.count
    assert_equal "large", result.first.slug
  end

  test "generate_clusters creates fallback clusters when AI unavailable" do
    result = Platform::Knowledge::LayerTwo.generate_clusters

    assert result.any?
    assert result.all? { |c| c.is_a?(KnowledgeCluster) }

    # Check that known fallback clusters were created
    slugs = result.map(&:slug)
    assert_includes slugs, "ottoman-heritage"
    assert_includes slugs, "gastronomy"
  end

  test "assign_to_clusters creates memberships based on keywords" do
    # Create a cluster with keywords
    cluster = KnowledgeCluster.create!(
      slug: "ottoman-heritage",
      name: "Osmansko nasljeđe",
      stats: { keywords: %w[most džamija osmanski] }
    )

    Platform::Knowledge::LayerTwo.assign_to_clusters

    cluster.reload

    # Should have found locations matching keywords
    assert cluster.member_count > 0
    assert cluster.cluster_memberships.any?
  end

  test "for_system_prompt returns formatted cluster list" do
    KnowledgeCluster.create!(slug: "heritage", name: "Heritage", member_count: 50)
    KnowledgeCluster.create!(slug: "food", name: "Food", member_count: 30)

    result = Platform::Knowledge::LayerTwo.for_system_prompt

    assert result.include?("## Available Clusters")
    assert result.include?("Heritage")
    assert result.include?("heritage")
    assert result.include?("50 members")
  end

  test "for_system_prompt returns empty string when no clusters" do
    result = Platform::Knowledge::LayerTwo.for_system_prompt

    assert_equal "", result
  end
end
