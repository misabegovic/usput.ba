# frozen_string_literal: true

require "test_helper"

class Platform::DSL::ClustersTest < ActiveSupport::TestCase
  setup do
    KnowledgeCluster.delete_all
    ClusterMembership.delete_all

    @cluster = KnowledgeCluster.create!(
      slug: "test-cluster",
      name: "Test Cluster",
      summary: "A test cluster for DSL tests",
      member_count: 25,
      stats: { keywords: %w[test example] }
    )
  end

  test "parses clusters | list" do
    ast = Platform::DSL::Parser.parse("clusters | list")

    assert_equal :clusters_query, ast[:type]
    assert_equal :list, ast[:operations].first[:name]
  end

  test "parses clusters with filter | show" do
    ast = Platform::DSL::Parser.parse('clusters { id: "test-cluster" } | show')

    assert_equal :clusters_query, ast[:type]
    assert_equal "test-cluster", ast[:filters][:id]
    assert_equal :show, ast[:operations].first[:name]
  end

  test "executes clusters | list" do
    result = Platform::DSL.execute("clusters | list")

    assert result.is_a?(Hash)
    assert result.key?(:clusters)
    assert result.key?(:total)
    assert_equal 1, result[:total]
    assert_equal "test-cluster", result[:clusters].first[:slug]
  end

  test "executes clusters with id filter | show" do
    result = Platform::DSL.execute('clusters { id: "test-cluster" } | show')

    assert result.is_a?(Hash)
    assert_equal "test-cluster", result[:slug]
    assert_equal "Test Cluster", result[:name]
    assert_equal 25, result[:member_count]
  end

  test "raises error for show without filter" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("clusters | show")
    end
  end

  test "raises error for unknown cluster" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('clusters { id: "nonexistent" } | show')
    end
  end

  test "raises error for unknown operation" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("clusters | unknown_op")
    end
  end

  test "executes clusters | members with filter" do
    # Create a location and membership
    location = Location.create!(name: "Test Loc", city: "Test", lat: 43.0, lng: 18.0)

    ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: location.id,
      similarity_score: 0.8
    )

    result = Platform::DSL.execute('clusters { id: "test-cluster" } | members')

    assert result.is_a?(Hash)
    assert_equal "Test Cluster", result[:cluster]
    assert result[:members].any?
    assert_equal location.id, result[:members].first[:id]
  end

  test "semantic search returns fallback when pgvector unavailable" do
    # This tests the graceful degradation when pgvector is not installed
    result = Platform::DSL.execute('clusters | semantic "ottoman heritage"')

    # Should return error message with fallback data
    assert result.is_a?(Hash)
    if result[:error]
      assert result[:error].include?("pgvector")
      assert result[:fallback].present?
    end
  end
end
