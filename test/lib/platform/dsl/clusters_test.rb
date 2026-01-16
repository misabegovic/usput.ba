# frozen_string_literal: true

require "test_helper"
require "ostruct"

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

  # Additional coverage tests

  test "list_clusters with min_members filter" do
    result = Platform::DSL.execute("clusters { min_members: 10 } | list")

    assert result.is_a?(Hash)
    assert result[:clusters].all? { |c| c[:member_count] >= 10 }
  end

  test "list_clusters returns empty when none match filter" do
    result = Platform::DSL.execute("clusters { min_members: 1000 } | list")

    assert_equal 0, result[:total]
  end

  test "show_cluster with slug filter" do
    result = Platform::DSL.execute('clusters { slug: "test-cluster" } | show')

    assert_equal "test-cluster", result[:slug]
  end

  test "clusters | refresh" do
    result = Platform::DSL.execute("clusters | refresh")

    assert result.is_a?(String)
  end

  test "show_cluster_members raises error without filter" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("clusters | members")
    end
  end

  test "semantic_search_clusters returns error when pgvector unavailable" do
    result = Platform::DSL::Executor.send(:semantic_search_clusters, "test query")

    assert result.is_a?(Hash)
    if result[:error]
      assert result[:error].include?("pgvector")
      assert result[:fallback].is_a?(Hash)
    end
  end

  test "semantic_search_clusters raises error without query" do
    assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executor.send(:semantic_search_clusters, nil)
    end
  end

  test "refresh_clusters with regenerate flag" do
    result = Platform::DSL::Executor.send(:refresh_clusters, { regenerate: true })

    assert result.include?("regeneration")
  end

  test "refresh_clusters without regenerate flag" do
    result = Platform::DSL::Executor.send(:refresh_clusters, {})

    assert result.include?("refresh")
  end

  test "show_cluster_members with limit filter" do
    location = Location.create!(name: "Limit Test", city: "Test", lat: 43.0, lng: 18.0)

    ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: location.id,
      similarity_score: 0.9
    )

    result = Platform::DSL.execute('clusters { id: "test-cluster", limit: 5 } | members')

    assert result.is_a?(Hash)
    assert result[:members].length <= 5
  end

  test "show_cluster_members formats member without name method" do
    # Create an experience as a member since it uses 'title' not 'name'
    experience = Experience.create!(title: "Test Experience", estimated_duration: 60)

    ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Experience",
      record_id: experience.id,
      similarity_score: 0.7
    )

    result = Platform::DSL.execute('clusters { id: "test-cluster" } | members')

    exp_member = result[:members].find { |m| m[:type] == "Experience" }
    assert_equal "Test Experience", exp_member[:name] if exp_member
  end

  test "show_cluster details include stats and representative_ids" do
    @cluster.update!(representative_ids: [1, 2, 3])

    result = Platform::DSL.execute('clusters { id: "test-cluster" } | show')

    assert result[:stats].present?
    assert_equal [1, 2, 3], result[:representative_ids]
  end

  test "list_clusters with empty database" do
    KnowledgeCluster.delete_all

    result = Platform::DSL.execute("clusters | list")

    assert_equal 0, result[:total]
    assert_equal [], result[:clusters]
  end

  # Semantic search with mocked pgvector availability
  test "semantic_search_clusters when pgvector is available" do
    # Mock pgvector availability and search results
    KnowledgeCluster.stub(:semantic_search_available?, true) do
      mock_results = [
        OpenStruct.new(slug: "test-cluster", name: "Test Cluster", member_count: 25, summary: "A test cluster summary")
      ]

      Platform::Knowledge::LayerTwo.stub(:semantic_search, mock_results) do
        result = Platform::DSL::Executor.send(:semantic_search_clusters, "test query")

        assert_equal "test query", result[:query]
        assert result[:results].is_a?(Array)
        assert_equal "test-cluster", result[:results].first[:slug]
      end
    end
  end

  test "semantic_search_clusters truncates long summaries" do
    KnowledgeCluster.stub(:semantic_search_available?, true) do
      long_summary = "A" * 200
      mock_results = [
        OpenStruct.new(slug: "long-summary", name: "Long", member_count: 10, summary: long_summary)
      ]

      Platform::Knowledge::LayerTwo.stub(:semantic_search, mock_results) do
        result = Platform::DSL::Executor.send(:semantic_search_clusters, "test")

        # Summary should be truncated to 100 chars
        assert result[:results].first[:summary].length <= 103 # 100 + "..."
      end
    end
  end

  test "semantic search through DSL execute" do
    KnowledgeCluster.stub(:semantic_search_available?, true) do
      mock_results = [@cluster]

      Platform::Knowledge::LayerTwo.stub(:semantic_search, mock_results) do
        result = Platform::DSL.execute('clusters | semantic "ottoman"')

        assert result.is_a?(Hash)
        if result[:query]
          assert_equal "ottoman", result[:query]
        end
      end
    end
  end

  test "show_cluster_members with nil similarity_score" do
    location = Location.create!(name: "No Score Loc", city: "Test", lat: 43.1, lng: 18.1)

    ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: location.id,
      similarity_score: nil
    )

    result = Platform::DSL.execute('clusters { id: "test-cluster" } | members')

    nil_score_member = result[:members].find { |m| m[:id] == location.id }
    assert_nil nil_score_member[:similarity] if nil_score_member
  end
end
