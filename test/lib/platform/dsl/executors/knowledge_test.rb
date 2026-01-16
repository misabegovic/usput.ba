# frozen_string_literal: true

require "test_helper"

class Platform::DSL::Executors::KnowledgeTest < ActiveSupport::TestCase
  setup do
    @knowledge_summary = KnowledgeSummary.create!(
      dimension: "city",
      dimension_value: "Sarajevo",
      summary: "Test summary for Sarajevo",
      stats: { locations_count: 10 },
      issues: [{ type: "missing_description", count: 2 }],
      patterns: { popular_category: "restaurant" },
      source_count: 10,
      generated_at: Time.current
    )

    @knowledge_cluster = KnowledgeCluster.create!(
      slug: "test-cluster",
      name: "Test Cluster",
      summary: "Test cluster summary",
      member_count: 5,
      stats: { avg_rating: 4.5 },
      representative_ids: [1, 2, 3]
    )
  end

  # ===================
  # Summaries Query Tests
  # ===================

  test "execute_summaries_query raises for unknown operation" do
    ast = {
      filters: {},
      operations: [{ name: :unknown_op }]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)
    end

    assert_match(/Nepoznata summaries operacija/i, error.message)
  end

  test "execute_summaries_query lists summaries overview" do
    ast = {
      filters: {},
      operations: [{ name: :list }]
    }

    result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

    assert result.is_a?(Hash)
    assert result[:total] >= 0
  end

  test "execute_summaries_query lists summaries by dimension" do
    ast = {
      filters: { dimension: "city" },
      operations: [{ name: :list }]
    }

    result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

    assert result.is_a?(Array)
  end

  test "execute_summaries_query lists summaries by city filter" do
    ast = {
      filters: { city: "Sarajevo" },
      operations: [{ name: :list }]
    }

    result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

    assert result.is_a?(Array)
  end

  test "execute_summaries_query shows summary" do
    Platform::Knowledge::LayerOne.stub(:get_summary, @knowledge_summary) do
      ast = {
        filters: { city: "Sarajevo" },
        operations: [{ name: :show }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

      assert_equal "city", result[:dimension]
      assert_equal "Sarajevo", result[:value]
      assert result[:summary].present?
    end
  end

  test "execute_summaries_query show raises without dimension filter" do
    ast = {
      filters: {},
      operations: [{ name: :show }]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)
    end

    assert_match(/Potreban filter/i, error.message)
  end

  test "execute_summaries_query show raises for non-existent summary" do
    Platform::Knowledge::LayerOne.stub(:get_summary, nil) do
      ast = {
        filters: { city: "NonExistent" },
        operations: [{ name: :show }]
      }

      error = assert_raises(Platform::DSL::ExecutionError) do
        Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)
      end

      assert_match(/ne postoji/i, error.message)
    end
  end

  test "execute_summaries_query shows issues for specific summary" do
    ast = {
      filters: { city: "Sarajevo" },
      operations: [{ name: :issues }]
    }

    result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

    assert result.is_a?(Array)
  end

  test "execute_summaries_query shows all issues" do
    ast = {
      filters: {},
      operations: [{ name: :issues }]
    }

    result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

    assert result.is_a?(Array)
  end

  test "execute_summaries_query refresh specific summary" do
    mock_summary = Object.new
    mock_summary.define_singleton_method(:to_short_format) { "formatted" }

    Platform::Knowledge::LayerOne.stub(:generate_summary, mock_summary) do
      ast = {
        filters: { city: "Sarajevo" },
        operations: [{ name: :refresh }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

      assert_match(/Refreshed/i, result)
    end
  end

  test "execute_summaries_query refresh all when no specific dimension" do
    Platform::SummaryGenerationJob.stub(:perform_later, nil) do
      ast = {
        filters: { dimension: "city" },  # dimension without value triggers full refresh
        operations: [{ name: :refresh }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

      assert_match(/Queued/i, result)
    end
  end

  test "execute_summaries_query refresh all" do
    Platform::SummaryGenerationJob.stub(:perform_later, nil) do
      ast = {
        filters: {},
        operations: [{ name: :refresh }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)

      assert_match(/Queued/i, result)
    end
  end

  # ===================
  # Clusters Query Tests
  # ===================

  test "execute_clusters_query raises for unknown operation" do
    ast = {
      filters: {},
      operations: [{ name: :unknown_op }]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)
    end

    assert_match(/Nepoznata clusters operacija/i, error.message)
  end

  test "execute_clusters_query lists clusters" do
    ast = {
      filters: {},
      operations: [{ name: :list }]
    }

    result = Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)

    assert result[:clusters].is_a?(Array)
    assert result[:total] >= 0
  end

  test "execute_clusters_query lists clusters with min_members filter" do
    ast = {
      filters: { min_members: 3 },
      operations: [{ name: :list }]
    }

    result = Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)

    assert result[:clusters].is_a?(Array)
  end

  test "execute_clusters_query shows cluster" do
    Platform::Knowledge::LayerTwo.stub(:get_cluster, @knowledge_cluster) do
      ast = {
        filters: { slug: "test-cluster" },
        operations: [{ name: :show }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)

      assert_equal "test-cluster", result[:slug]
      assert_equal "Test Cluster", result[:name]
    end
  end

  test "execute_clusters_query show raises without slug/id" do
    ast = {
      filters: {},
      operations: [{ name: :show }]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)
    end

    assert_match(/Potreban filter/i, error.message)
  end

  test "execute_clusters_query show raises for non-existent cluster" do
    Platform::Knowledge::LayerTwo.stub(:get_cluster, nil) do
      ast = {
        filters: { slug: "non-existent" },
        operations: [{ name: :show }]
      }

      error = assert_raises(Platform::DSL::ExecutionError) do
        Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)
      end

      assert_match(/ne postoji/i, error.message)
    end
  end

  test "execute_clusters_query semantic search raises without query" do
    ast = {
      filters: {},
      operations: [{ name: :semantic, args: nil }]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)
    end

    assert_match(/zahtijeva upit/i, error.message)
  end

  test "execute_clusters_query semantic search returns fallback when not available" do
    KnowledgeCluster.stub(:semantic_search_available?, false) do
      ast = {
        filters: {},
        operations: [{ name: :semantic, args: ["test query"] }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)

      assert result[:error].present?
      assert result[:fallback].present?
    end
  end

  test "execute_clusters_query semantic search works when available" do
    KnowledgeCluster.stub(:semantic_search_available?, true) do
      Platform::Knowledge::LayerTwo.stub(:semantic_search, [@knowledge_cluster]) do
        ast = {
          filters: {},
          operations: [{ name: :semantic, args: ["test query"] }]
        }

        result = Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)

        assert_equal "test query", result[:query]
        assert result[:results].is_a?(Array)
      end
    end
  end

  test "execute_clusters_query shows members raises without slug" do
    ast = {
      filters: {},
      operations: [{ name: :members }]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)
    end

    assert_match(/Potreban filter/i, error.message)
  end

  test "execute_clusters_query shows members raises for non-existent cluster" do
    ast = {
      filters: { slug: "non-existent" },
      operations: [{ name: :members }]
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)
    end

    assert_match(/ne postoji/i, error.message)
  end

  test "execute_clusters_query refresh queues job" do
    Platform::ClusterGenerationJob.stub(:perform_later, nil) do
      ast = {
        filters: {},
        operations: [{ name: :refresh }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)

      assert_match(/Queued/i, result)
    end
  end

  test "execute_clusters_query refresh with regenerate flag" do
    Platform::ClusterGenerationJob.stub(:perform_later, nil) do
      ast = {
        filters: { regenerate: true },
        operations: [{ name: :refresh }]
      }

      result = Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)

      assert_match(/regeneration/i, result)
    end
  end

  # ===================
  # Helper Method Tests
  # ===================

  test "extract_dimension_and_value extracts city" do
    dimension, value = Platform::DSL::Executors::Knowledge.send(
      :extract_dimension_and_value,
      { city: "Sarajevo" }
    )

    assert_equal "city", dimension
    assert_equal "Sarajevo", value
  end

  test "extract_dimension_and_value extracts category" do
    dimension, value = Platform::DSL::Executors::Knowledge.send(
      :extract_dimension_and_value,
      { category: "restaurants" }
    )

    assert_equal "category", dimension
    assert_equal "restaurants", value
  end

  test "extract_dimension_and_value extracts region" do
    dimension, value = Platform::DSL::Executors::Knowledge.send(
      :extract_dimension_and_value,
      { region: "Herzegovina" }
    )

    assert_equal "region", dimension
    assert_equal "Herzegovina", value
  end

  test "extract_dimension_and_value extracts explicit dimension and value" do
    dimension, value = Platform::DSL::Executors::Knowledge.send(
      :extract_dimension_and_value,
      { dimension: "custom", value: "test" }
    )

    assert_equal "custom", dimension
    assert_equal "test", value
  end

  test "extract_dimension_and_value returns nil for empty filters" do
    dimension, value = Platform::DSL::Executors::Knowledge.send(
      :extract_dimension_and_value,
      {}
    )

    assert_nil dimension
    assert_nil value
  end

  # Additional branch coverage tests

  test "execute_summaries_query with nil operations" do
    ast = {
      filters: {},
      operations: nil
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_summaries_query(ast)
    end

    assert_match(/Nepoznata summaries operacija/i, error.message)
  end

  test "execute_clusters_query with nil operations" do
    ast = {
      filters: {},
      operations: nil
    }

    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL::Executors::Knowledge.execute_clusters_query(ast)
    end

    assert_match(/Nepoznata clusters operacija/i, error.message)
  end
end
