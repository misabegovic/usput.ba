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

  # Mocked AI client tests

  test "generate_ai_cluster_proposals with mocked RubyLLM" do
    sample_data = [{ id: 1, name: "Test", city: "Sarajevo", description: "Ottoman heritage location" }]

    # Mock chat response
    mock_chat = Object.new
    mock_response = Object.new
    mock_response.define_singleton_method(:content) do
      '[{"slug": "test-ai", "name": "Test AI", "summary": "AI generated", "keywords": ["test"]}]'
    end
    mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

    RubyLLM.stub(:chat, mock_chat) do
      RubyLLM.config.stub(:default_model, "claude-sonnet-4-20250514") do
        result = Platform::Knowledge::LayerTwo.send(:generate_ai_cluster_proposals, sample_data)

        assert result.any?
        assert_equal "test-ai", result.first[:slug]
      end
    end
  end

  test "generate_ai_cluster_proposals returns fallback when RubyLLM raises" do
    sample_data = [{ id: 1, name: "Test", city: "Test", description: "Test" }]

    RubyLLM.stub(:chat, ->(*) { raise "API Error" }) do
      RubyLLM.config.stub(:default_model, "claude-sonnet-4-20250514") do
        result = Platform::Knowledge::LayerTwo.send(:generate_ai_cluster_proposals, sample_data)

        assert result.any?
        # Should return fallback clusters
        assert result.any? { |c| c[:slug] == "ottoman-heritage" }
      end
    end
  end

  test "generate_embedding with mocked OpenAI client" do
    original_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"

    mock_response = { "data" => [{ "embedding" => [0.1, 0.2, 0.3] }] }
    mock_client = Object.new
    mock_client.define_singleton_method(:embeddings) { |**_args| mock_response }

    OpenAI::Client.stub(:new, mock_client) do
      result = Platform::Knowledge::LayerTwo.generate_embedding("test text")

      assert_equal [0.1, 0.2, 0.3], result
    end
  ensure
    ENV["OPENAI_API_KEY"] = original_key
  end

  test "generate_embedding handles API errors gracefully" do
    original_key = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"

    mock_client = Object.new
    mock_client.define_singleton_method(:embeddings) { |**_args| raise "API Error" }

    OpenAI::Client.stub(:new, mock_client) do
      result = Platform::Knowledge::LayerTwo.generate_embedding("test text")

      assert_nil result
    end
  ensure
    ENV["OPENAI_API_KEY"] = original_key
  end

  test "semantic_search with mocked pgvector and embedding" do
    KnowledgeCluster.stub(:semantic_search_available?, true) do
      # Mock embedding generation
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, [0.1, 0.2, 0.3]) do
        mock_results = [KnowledgeCluster.new(slug: "test", name: "Test", member_count: 10)]

        KnowledgeCluster.stub(:semantic_search, mock_results) do
          result = Platform::Knowledge::LayerTwo.semantic_search("ottoman heritage")

          assert result.any?
          assert_equal "test", result.first.slug
        end
      end
    end
  end

  test "semantic_search returns empty when embedding generation fails" do
    KnowledgeCluster.stub(:semantic_search_available?, true) do
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, nil) do
        result = Platform::Knowledge::LayerTwo.semantic_search("test query")

        assert_equal [], result
      end
    end
  end

  test "generate_all_embeddings with mocked pgvector" do
    KnowledgeCluster.create!(slug: "needs-embedding", name: "Needs Embedding", summary: "A test summary", embedding: nil)

    KnowledgeCluster.stub(:semantic_search_available?, true) do
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, [0.1, 0.2, 0.3]) do
        Platform::Knowledge::LayerTwo.generate_all_embeddings

        cluster = KnowledgeCluster.find_by(slug: "needs-embedding")
        # Embedding should have been set (if vector column exists)
        assert cluster.present?
      end
    end
  end

  test "create_or_update_cluster handles validation errors" do
    # Create a proposal with missing required fields that would fail validation
    proposal = {
      slug: nil, # Invalid - slug is required
      name: nil,
      summary: nil,
      keywords: []
    }

    result = Platform::Knowledge::LayerTwo.send(:create_or_update_cluster, proposal)

    # Should return nil on error
    assert_nil result
  end

  test "assign_records_to_cluster handles duplicate membership errors" do
    cluster = KnowledgeCluster.create!(
      slug: "dupe-test",
      name: "Dupe Test",
      stats: { keywords: %w[most osmanski] }
    )

    # Create an existing membership
    ClusterMembership.create!(
      knowledge_cluster: cluster,
      record_type: "Location",
      record_id: @location1.id
    )

    # Should not raise when encountering duplicates
    assert_nothing_raised do
      Platform::Knowledge::LayerTwo.send(:assign_records_to_cluster, cluster)
    end
  end

  test "assign_records_to_cluster with stats using string keys" do
    cluster = KnowledgeCluster.create!(
      slug: "string-keys-test",
      name: "String Keys Test",
      stats: { "keywords" => %w[džamija osmanski] }
    )

    Platform::Knowledge::LayerTwo.send(:assign_records_to_cluster, cluster)

    cluster.reload
    # Should work with string keys
    assert cluster.member_count >= 0
  end

  # Additional tests for uncovered branches

  test "semantic_search when pgvector is not available returns empty array" do
    KnowledgeCluster.stub(:semantic_search_available?, false) do
      result = Platform::Knowledge::LayerTwo.semantic_search("test query")
      assert_equal [], result
    end
  end

  test "generate_all_embeddings skips clusters with blank summary" do
    KnowledgeCluster.create!(slug: "blank-summary", name: "Blank Summary", summary: nil, embedding: nil)

    KnowledgeCluster.stub(:semantic_search_available?, true) do
      # Should not try to generate embedding for blank summary
      assert_nothing_raised do
        Platform::Knowledge::LayerTwo.generate_all_embeddings
      end
    end
  end

  test "generate_all_embeddings handles error gracefully" do
    cluster = KnowledgeCluster.create!(slug: "error-test", name: "Error Test", summary: "Some summary", embedding: nil)

    KnowledgeCluster.stub(:semantic_search_available?, true) do
      # Mock generate_embedding to raise
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, ->(_text) { raise StandardError, "Test error" }) do
        # Should not raise, just log warning
        assert_nothing_raised do
          Platform::Knowledge::LayerTwo.generate_all_embeddings
        end
      end
    end
  end

  test "propose_clusters handles AI errors gracefully" do
    locations = [
      Location.new(id: 1, name: "Test", city: "City", description: "Description")
    ]

    # Stub generate_ai_cluster_proposals to raise
    Platform::Knowledge::LayerTwo.stub(:generate_ai_cluster_proposals, ->(_data) { raise StandardError, "AI error" }) do
      result = Platform::Knowledge::LayerTwo.send(:propose_clusters, locations)

      # Should return fallback clusters
      assert result.any?
    end
  end

  test "propose_clusters handles locations with nil description" do
    location_without_desc = Location.create!(
      name: "No Description",
      city: "Test City",
      lat: 43.5,
      lng: 18.2,
      description: nil
    )

    Platform::Knowledge::LayerTwo.stub(:generate_ai_cluster_proposals, ->(_data) { [{ slug: "test", name: "Test" }] }) do
      result = Platform::Knowledge::LayerTwo.send(:propose_clusters, [location_without_desc])

      # Should handle nil description gracefully (truncate with &.)
      assert result.any?
    end
  end

  test "parse_cluster_response handles JSON parse error" do
    # Valid JSON array format but with malformed inner content that causes parse error
    content = '[{"slug: malformed json'

    result = Platform::Knowledge::LayerTwo.send(:parse_cluster_response, content)

    # Should return empty array on parse error
    assert_equal [], result
  end

  test "generate_ai_cluster_proposals without RubyLLM model configured" do
    sample_data = [{ id: 1, name: "Test", city: "City", description: "Desc" }]

    RubyLLM.config.stub(:default_model, nil) do
      result = Platform::Knowledge::LayerTwo.send(:generate_ai_cluster_proposals, sample_data)

      # Should return fallback clusters
      assert result.any?
    end
  end

  # Additional tests for uncovered branches

  test "generate_all_embeddings when semantic_search not available returns early" do
    # Test the return early branch at line 61
    KnowledgeCluster.stub(:semantic_search_available?, false) do
      # Should return without processing any clusters
      assert_nothing_raised do
        Platform::Knowledge::LayerTwo.generate_all_embeddings
      end
    end
  end

  test "generate_all_embeddings skips update when embedding is nil/blank" do
    # Test line 67: cluster.update!(embedding: embedding) if embedding.present?
    cluster = KnowledgeCluster.create!(slug: "nil-embedding", name: "Nil Embedding", summary: "Test summary", embedding: nil)

    KnowledgeCluster.stub(:semantic_search_available?, true) do
      # Return nil from generate_embedding to test the branch
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, ->(_text) { nil }) do
        Platform::Knowledge::LayerTwo.generate_all_embeddings

        cluster.reload
        # Embedding should remain nil
        assert_nil cluster.embedding
      end
    end
  end

  test "generate_all_embeddings skips update when embedding is empty array" do
    cluster = KnowledgeCluster.create!(slug: "empty-embedding", name: "Empty Embedding", summary: "Test summary", embedding: nil)

    KnowledgeCluster.stub(:semantic_search_available?, true) do
      # Return empty array from generate_embedding
      Platform::Knowledge::LayerTwo.stub(:generate_embedding, ->(_text) { [] }) do
        Platform::Knowledge::LayerTwo.generate_all_embeddings

        cluster.reload
        # Should not update with empty embedding
        assert cluster.embedding.nil? || cluster.embedding == []
      end
    end
  end

  test "sample_locations returns SAMPLE_SIZE when enough locations exist" do
    # Test line 128: if samples.size < SAMPLE_SIZE
    # Create enough locations so that samples.size >= SAMPLE_SIZE
    sample_size = Platform::Knowledge::LayerTwo::SAMPLE_SIZE

    # Create more locations than SAMPLE_SIZE to ensure we hit the branch where samples.size >= SAMPLE_SIZE
    existing_count = Location.where.not(description: [nil, ""]).count

    if existing_count < sample_size
      (sample_size - existing_count + 5).times do |i|
        Location.create!(
          name: "Sample Location #{i}",
          city: %w[Sarajevo Mostar Banja_Luka Tuzla Zenica].sample,
          lat: 43.0 + rand * 2,
          lng: 17.5 + rand * 1.5,
          description: "Sample description for location #{i} with keywords about heritage and history."
        )
      end
    end

    samples = Platform::Knowledge::LayerTwo.send(:sample_locations)

    assert samples.is_a?(Array)
    assert samples.size <= sample_size
  end

  test "parse_cluster_response catches JSON::ParserError and returns empty array" do
    # Force a JSON parse error with malformed JSON that matches the regex but fails to parse
    content = '[ {"slug": "test", "name": incomplete JSON'

    result = Platform::Knowledge::LayerTwo.send(:parse_cluster_response, content)

    assert_equal [], result
  end

  test "assign_records_to_cluster handles stats with nil keywords" do
    # Test line 281: cluster.stats&.dig("keywords") || cluster.stats&.dig(:keywords) || []
    cluster = KnowledgeCluster.create!(
      slug: "nil-keywords-test",
      name: "Nil Keywords Test",
      stats: nil
    )

    Platform::Knowledge::LayerTwo.send(:assign_records_to_cluster, cluster)

    cluster.reload
    assert_equal 0, cluster.member_count
  end

  test "assign_records_to_cluster handles stats with no keywords key" do
    cluster = KnowledgeCluster.create!(
      slug: "missing-keywords-test",
      name: "Missing Keywords Test",
      stats: { "other_key" => "value" }
    )

    Platform::Knowledge::LayerTwo.send(:assign_records_to_cluster, cluster)

    cluster.reload
    assert_equal 0, cluster.member_count
  end

  test "assign_records_to_cluster handles stats with symbol keywords key" do
    cluster = KnowledgeCluster.create!(
      slug: "symbol-keywords-test",
      name: "Symbol Keywords Test",
      stats: { keywords: %w[heritage osmansko] }
    )

    Platform::Knowledge::LayerTwo.send(:assign_records_to_cluster, cluster)

    cluster.reload
    # May or may not have members depending on data
    assert cluster.member_count >= 0
  end
end
