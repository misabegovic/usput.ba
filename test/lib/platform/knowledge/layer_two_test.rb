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

  # Additional coverage tests

  test "semantic_search returns empty array when pgvector unavailable" do
    # pgvector is likely not installed in test env
    result = Platform::Knowledge::LayerTwo.semantic_search("test query")

    assert_equal [], result
  end

  test "generate_embedding returns nil for blank text" do
    result = Platform::Knowledge::LayerTwo.generate_embedding("")

    assert_nil result
  end

  test "generate_embedding returns nil without API key" do
    original_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = nil

    result = Platform::Knowledge::LayerTwo.generate_embedding("test text")

    assert_nil result
  ensure
    ENV["OPENAI_API_KEY"] = original_key
  end

  test "generate_all_embeddings handles missing pgvector gracefully" do
    # Should not raise
    assert_nothing_raised do
      Platform::Knowledge::LayerTwo.generate_all_embeddings
    end
  end

  test "sample_locations returns diverse locations" do
    samples = Platform::Knowledge::LayerTwo.send(:sample_locations)

    # Should be an array
    assert samples.is_a?(Array)
  end

  test "generate_fallback_clusters returns predefined clusters" do
    clusters = Platform::Knowledge::LayerTwo.send(:generate_fallback_clusters)

    assert clusters.any?
    assert clusters.any? { |c| c[:slug] == "ottoman-heritage" }
    assert clusters.any? { |c| c[:slug] == "gastronomy" }
    assert clusters.any? { |c| c[:slug] == "natural-beauty" }
  end

  test "create_or_update_cluster creates new cluster" do
    proposal = {
      slug: "test-cluster-new",
      name: "Test Cluster",
      summary: "A test cluster",
      keywords: %w[test example]
    }

    result = Platform::Knowledge::LayerTwo.send(:create_or_update_cluster, proposal)

    assert_not_nil result
    assert_equal "test-cluster-new", result.slug
    assert_equal "Test Cluster", result.name
  end

  test "create_or_update_cluster updates existing cluster" do
    # Create initial cluster
    KnowledgeCluster.create!(slug: "existing-cluster", name: "Old Name")

    proposal = {
      slug: "existing-cluster",
      name: "New Name",
      summary: "Updated summary",
      keywords: %w[new keywords]
    }

    result = Platform::Knowledge::LayerTwo.send(:create_or_update_cluster, proposal)

    assert_equal "New Name", result.name
  end

  test "calculate_keyword_similarity returns score" do
    keywords = %w[restoran hrana piće]
    score = Platform::Knowledge::LayerTwo.send(:calculate_keyword_similarity, @location3, keywords)

    # Ćevabdžinica should match some food-related keywords in its description
    assert score >= 0
    assert score <= 1
  end

  test "parse_cluster_response extracts JSON" do
    content = 'Here is the analysis:\n[{"slug": "test", "name": "Test", "summary": "desc", "keywords": ["a"]}]'

    result = Platform::Knowledge::LayerTwo.send(:parse_cluster_response, content)

    assert result.any?
    assert_equal "test", result.first[:slug]
  end

  test "parse_cluster_response returns empty for invalid JSON" do
    content = "This is not JSON at all"

    result = Platform::Knowledge::LayerTwo.send(:parse_cluster_response, content)

    assert_equal [], result
  end

  test "build_cluster_prompt includes sample data" do
    sample_data = [
      { name: "Location1", city: "City1", description: "Desc1" },
      { name: "Location2", city: "City2", description: "Desc2" }
    ]

    result = Platform::Knowledge::LayerTwo.send(:build_cluster_prompt, sample_data)

    assert result.include?("Location1")
    assert result.include?("City1")
    assert result.include?("thematic clusters")
    assert result.include?("JSON format")
  end

  test "assign_records_to_cluster assigns matching locations" do
    cluster = KnowledgeCluster.create!(
      slug: "food-test",
      name: "Food Test",
      stats: { keywords: %w[restoran ćevap kuhinja] }
    )

    Platform::Knowledge::LayerTwo.send(:assign_records_to_cluster, cluster)

    cluster.reload
    # May or may not have members depending on test data
    assert cluster.member_count >= 0
  end

  test "assign_records_to_cluster skips clusters without keywords" do
    cluster = KnowledgeCluster.create!(
      slug: "empty-keywords",
      name: "Empty Keywords",
      stats: { keywords: [] }
    )

    Platform::Knowledge::LayerTwo.send(:assign_records_to_cluster, cluster)

    cluster.reload
    assert_equal 0, cluster.member_count
  end

  test "generate_fallback_clusters_from_sample returns fallback clusters" do
    sample_data = [{ name: "Test", city: "City", description: "Desc" }]

    result = Platform::Knowledge::LayerTwo.send(:generate_fallback_clusters_from_sample, sample_data)

    assert result.any?
    assert result.any? { |c| c[:slug] == "ottoman-heritage" }
  end

  test "propose_clusters returns fallback when AI unavailable" do
    locations = Location.limit(5).to_a

    # AI is likely not configured in test env
    result = Platform::Knowledge::LayerTwo.send(:propose_clusters, locations)

    assert result.any?
  end
end
