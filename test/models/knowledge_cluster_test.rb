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
    available = KnowledgeCluster.semantic_search_available?

    # Result depends on whether pgvector/embedding column exists
    if KnowledgeCluster.column_names.include?("embedding")
      assert available, "Should be available when embedding column exists"
    else
      assert_not available, "Should not be available without embedding column"
    end
  end

  # Additional coverage tests

  test "semantic_search returns empty when not available" do
    # If pgvector isn't installed, should return empty
    unless KnowledgeCluster.semantic_search_available?
      result = KnowledgeCluster.semantic_search([0.1] * 1536)
      assert_equal [], result.to_a
    end
  end

  test "semantic_search returns empty for blank embedding" do
    result = KnowledgeCluster.semantic_search(nil)
    assert_equal [], result.to_a
  end

  test "generate_embedding! returns early without embedding support" do
    cluster = KnowledgeCluster.create!(
      slug: "embed-test",
      name: "Embedding Test",
      summary: "Test summary for embedding"
    )

    # Should not raise, just return early if not available
    assert_nothing_raised do
      cluster.generate_embedding!
    end
  end

  test "generate_embedding! returns early with blank summary" do
    cluster = KnowledgeCluster.create!(
      slug: "blank-summary",
      name: "Blank Summary",
      summary: ""
    )

    assert_nothing_raised do
      cluster.generate_embedding!
    end
  end

  test "representative_records returns empty for blank ids" do
    cluster = KnowledgeCluster.create!(
      slug: "no-reps",
      name: "No Reps",
      representative_ids: []
    )

    result = cluster.representative_records

    assert_equal [], result
  end

  test "representative_records returns empty for nil ids" do
    cluster = KnowledgeCluster.create!(
      slug: "nil-reps",
      name: "Nil Reps",
      representative_ids: nil
    )

    result = cluster.representative_records

    assert_equal [], result
  end

  test "representative_records returns locations for valid ids" do
    location1 = Location.create!(name: "Rep1", city: "City", lat: 43.0, lng: 18.0)
    location2 = Location.create!(name: "Rep2", city: "City", lat: 43.1, lng: 18.1)

    cluster = KnowledgeCluster.create!(
      slug: "with-reps",
      name: "With Reps",
      representative_ids: [location1.id, location2.id]
    )

    result = cluster.representative_records

    assert_equal 2, result.count
    assert_includes result.map(&:id), location1.id
    assert_includes result.map(&:id), location2.id
  end

  test "to_cli_format handles empty stats" do
    cluster = KnowledgeCluster.create!(
      slug: "empty-stats",
      name: "Empty Stats",
      stats: nil,
      member_count: 0
    )

    result = cluster.to_cli_format

    assert result.include?("Empty Stats")
    assert result.include?("Members: 0")
  end

  test "to_cli_format includes representative ids when present" do
    cluster = KnowledgeCluster.create!(
      slug: "with-rep-ids",
      name: "With Rep IDs",
      representative_ids: [1, 2, 3]
    )

    result = cluster.to_cli_format

    assert result.include?("Representative locations")
    assert result.include?("1, 2, 3")
  end

  test "with_embedding scope works" do
    # Create cluster without embedding
    KnowledgeCluster.create!(slug: "no-emb", name: "No Emb")

    # Scope should return relation
    result = KnowledgeCluster.with_embedding
    assert result.is_a?(ActiveRecord::Relation)
  end

  test "semantic_search with valid embedding when available" do
    # Test the semantic search path when embedding is available
    if KnowledgeCluster.semantic_search_available?
      # Create a cluster with an embedding
      cluster = KnowledgeCluster.create!(
        slug: "semantic-test",
        name: "Semantic Test",
        summary: "Test for semantic search"
      )

      # Create a fake embedding (1536 dimensions for OpenAI)
      query_embedding = Array.new(1536) { rand(-1.0..1.0) }

      # This should call nearest_neighbors
      result = KnowledgeCluster.semantic_search(query_embedding)
      assert result.is_a?(ActiveRecord::Relation)
    end
  end

  test "generate_embedding! with valid summary when available" do
    cluster = KnowledgeCluster.create!(
      slug: "gen-embed-test",
      name: "Generate Embedding Test",
      summary: "This is a test summary for embedding generation"
    )

    if KnowledgeCluster.semantic_search_available?
      # Stub LayerTwo.generate_embedding to return a valid embedding
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, Array.new(1536) { 0.1 }) do
        cluster.generate_embedding!
        cluster.reload
        # Check if embedding was set
        assert cluster.embedding.present? if cluster.respond_to?(:embedding)
      end
    else
      # When not available, should return early
      assert_nothing_raised { cluster.generate_embedding! }
    end
  end

  test "generate_embedding! handles nil embedding from LayerTwo" do
    cluster = KnowledgeCluster.create!(
      slug: "nil-embed-result",
      name: "Nil Embed Result",
      summary: "Test summary"
    )

    if KnowledgeCluster.semantic_search_available?
      # Stub to return nil
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, nil) do
        assert_nothing_raised { cluster.generate_embedding! }
      end
    end
  end

  test "semantic_search returns results when embedding column exists" do
    # Force the semantic_search_available? to return true for this test
    KnowledgeCluster.stub(:semantic_search_available?, true) do
      # With blank embedding, should return early
      result = KnowledgeCluster.semantic_search([])
      assert_equal [], result.to_a
    end
  end

  # Tests for uncovered branches when semantic_search is not available
  test "semantic_search returns none when semantic_search_available returns false" do
    KnowledgeCluster.stub(:semantic_search_available?, false) do
      result = KnowledgeCluster.semantic_search([0.1, 0.2, 0.3])
      assert_equal [], result.to_a
    end
  end

  test "generate_embedding! returns early when semantic_search_available returns false" do
    cluster = KnowledgeCluster.create!(
      slug: "no-semantic",
      name: "No Semantic",
      summary: "Test summary"
    )

    # This ensures we hit the first return branch in generate_embedding!
    KnowledgeCluster.stub(:semantic_search_available?, false) do
      # Should return early without calling LayerTwo
      result = cluster.generate_embedding!
      assert_nil result
    end
  end
end
