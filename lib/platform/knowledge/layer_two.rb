# frozen_string_literal: true

module Platform
  module Knowledge
    # Layer Two: Semantic Clusters
    #
    # Provides conceptual groupings of records for semantic reasoning.
    # Clusters are AI-generated based on content patterns and themes.
    #
    # DSL commands:
    #   clusters | list
    #   clusters { id: "ottoman-heritage" } | show
    #   clusters | semantic "ottoman heritage" | top 5
    #
    class LayerTwo
      SAMPLE_SIZE = 20

      class << self
        # Get or generate a cluster by slug
        def get_cluster(slug)
          KnowledgeCluster.find_by(slug: slug)
        end

        # List all clusters
        def list_clusters
          KnowledgeCluster.by_member_count
        end

        # Semantic search across clusters (requires pgvector)
        def semantic_search(query, limit: 5)
          return [] unless KnowledgeCluster.semantic_search_available?

          # Generate embedding for query
          query_embedding = generate_embedding(query)
          return [] if query_embedding.blank?

          KnowledgeCluster.semantic_search(query_embedding, limit: limit)
        end

        # Generate embedding using OpenAI
        def generate_embedding(text)
          return nil if text.blank?
          return nil unless ENV["OPENAI_API_KEY"].present?

          client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
          response = client.embeddings(
            parameters: {
              model: "text-embedding-ada-002",
              input: text.truncate(8000)
            }
          )

          response.dig("data", 0, "embedding")
        rescue StandardError => e
          Rails.logger.warn "[Platform::Knowledge::LayerTwo] Embedding generation failed: #{e.message}"
          nil
        end

        # Generate embeddings for all clusters
        def generate_all_embeddings
          return unless KnowledgeCluster.semantic_search_available?

          KnowledgeCluster.where(embedding: nil).find_each do |cluster|
            next if cluster.summary.blank?

            embedding = generate_embedding(cluster.summary)
            cluster.update!(embedding: embedding) if embedding.present?
          rescue StandardError => e
            Rails.logger.warn "[Platform::Knowledge::LayerTwo] Failed to generate embedding for #{cluster.slug}: #{e.message}"
          end
        end

        # Generate clusters based on content analysis
        def generate_clusters
          # Sample diverse locations for analysis
          locations = sample_locations

          return [] if locations.empty?

          # Use AI to propose cluster themes
          cluster_proposals = propose_clusters(locations)

          # Create or update clusters
          cluster_proposals.map do |proposal|
            create_or_update_cluster(proposal)
          end.compact
        end

        # Assign records to clusters
        def assign_to_clusters
          clusters = KnowledgeCluster.all

          clusters.each do |cluster|
            assign_records_to_cluster(cluster)
          end
        end

        # Get summary for system prompt
        def for_system_prompt
          clusters = KnowledgeCluster.by_member_count.limit(10)

          return "" if clusters.empty?

          lines = ["## Available Clusters"]
          clusters.each do |cluster|
            lines << "- #{cluster.name} (#{cluster.slug}): #{cluster.member_count} members"
          end

          lines.join("\n")
        end

        private

        def sample_locations
          # Stratified sampling: get diverse locations
          cities = Location.distinct.pluck(:city).compact.take(5)

          samples = []
          cities.each do |city|
            samples += Location.where(city: city)
                               .where.not(description: [nil, ""])
                               .order("RANDOM()")
                               .limit(SAMPLE_SIZE / cities.size)
                               .to_a
          end

          # Fill remaining with random if needed
          if samples.size < SAMPLE_SIZE
            remaining = SAMPLE_SIZE - samples.size
            samples += Location.where.not(id: samples.map(&:id))
                               .where.not(description: [nil, ""])
                               .order("RANDOM()")
                               .limit(remaining)
                               .to_a
          end

          samples
        end

        def propose_clusters(locations)
          # Prepare sample data for AI
          sample_data = locations.map do |loc|
            {
              id: loc.id,
              name: loc.name,
              city: loc.city,
              description: loc.description&.truncate(200)
            }
          end

          # Use AI to propose clusters
          begin
            generate_ai_cluster_proposals(sample_data)
          rescue StandardError => e
            Rails.logger.warn "[Platform::Knowledge::LayerTwo] AI unavailable: #{e.message}"
            generate_fallback_clusters(locations)
          end
        end

        def generate_ai_cluster_proposals(sample_data)
          return generate_fallback_clusters_from_sample(sample_data) unless RubyLLM.config.default_model.present?

          prompt = build_cluster_prompt(sample_data)
          chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")
          response = chat.ask(prompt)

          parse_cluster_response(response.content)
        rescue StandardError => e
          Rails.logger.warn "[Platform::Knowledge::LayerTwo] AI cluster generation failed: #{e.message}"
          generate_fallback_clusters_from_sample(sample_data)
        end

        def build_cluster_prompt(sample_data)
          <<~PROMPT
            Analyze these tourism locations from Bosnia and Herzegovina and propose 5-8 thematic clusters.

            Sample locations:
            #{sample_data.map { |d| "- #{d[:name]} (#{d[:city]}): #{d[:description]}" }.join("\n")}

            For each cluster, provide:
            1. A URL-safe slug (e.g., "ottoman-heritage", "adventure-sports")
            2. A descriptive name in Bosnian
            3. A brief summary of what locations belong in this cluster
            4. Keywords that would match locations to this cluster

            Respond in JSON format:
            [
              {
                "slug": "ottoman-heritage",
                "name": "Osmansko nasljeđe",
                "summary": "Lokacije vezane za osmansku arhitekturu, historiju i kulturu...",
                "keywords": ["džamija", "most", "čaršija", "bezistan", "hamam"]
              }
            ]
          PROMPT
        end

        def parse_cluster_response(content)
          # Extract JSON from response
          json_match = content.match(/\[[\s\S]*\]/)
          return [] unless json_match

          proposals = JSON.parse(json_match[0])
          proposals.map do |p|
            {
              slug: p["slug"],
              name: p["name"],
              summary: p["summary"],
              keywords: p["keywords"] || []
            }
          end
        rescue JSON::ParserError => e
          Rails.logger.warn "[Platform::Knowledge::LayerTwo] Failed to parse AI response: #{e.message}"
          []
        end

        def generate_fallback_clusters(_locations = nil)
          # Predefined clusters for BiH tourism
          [
            {
              slug: "ottoman-heritage",
              name: "Osmansko nasljeđe",
              summary: "Džamije, mostovi, čaršije i drugi objekti iz osmanskog perioda",
              keywords: %w[džamija most čaršija bezistan hamam osmanski]
            },
            {
              slug: "natural-beauty",
              name: "Prirodne ljepote",
              summary: "Rijeke, planine, vodopadi i prirodni parkovi",
              keywords: %w[rijeka planina vodopad park priroda jezero šuma]
            },
            {
              slug: "gastronomy",
              name: "Gastronomija",
              summary: "Restorani, kafane i tradicionalna kuhinja",
              keywords: %w[restoran kafana ćevapi burek pita hrana piće]
            },
            {
              slug: "adventure-sports",
              name: "Avanturistički sportovi",
              summary: "Rafting, hiking, paragliding i druge aktivnosti",
              keywords: %w[rafting hiking planinarenje paragliding avantura sport]
            },
            {
              slug: "religious-sites",
              name: "Vjerski objekti",
              summary: "Džamije, crkve, sinagoge i druga vjerska mjesta",
              keywords: %w[džamija crkva sinagoga samostan tekija vjerski]
            },
            {
              slug: "museums-culture",
              name: "Muzeji i kultura",
              summary: "Muzeji, galerije i kulturne institucije",
              keywords: %w[muzej galerija kultura umjetnost izložba]
            }
          ]
        end

        def generate_fallback_clusters_from_sample(sample_data)
          # Return fallback clusters regardless of sample
          generate_fallback_clusters
        end

        def create_or_update_cluster(proposal)
          cluster = KnowledgeCluster.find_or_initialize_by(slug: proposal[:slug])

          cluster.assign_attributes(
            name: proposal[:name],
            summary: proposal[:summary],
            stats: { keywords: proposal[:keywords] }
          )

          cluster.save!
          cluster
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[Platform::Knowledge::LayerTwo] Failed to create cluster: #{e.message}"
          nil
        end

        def assign_records_to_cluster(cluster)
          keywords = cluster.stats&.dig("keywords") || cluster.stats&.dig(:keywords) || []

          return if keywords.empty?

          # Build search pattern from keywords
          pattern = keywords.join("|")

          # Find matching locations
          matching_locations = Location.where(
            "name ILIKE ANY(ARRAY[?]) OR description ILIKE ANY(ARRAY[?])",
            keywords.map { |k| "%#{k}%" },
            keywords.map { |k| "%#{k}%" }
          ).limit(100)

          # Create memberships
          matching_locations.each do |location|
            ClusterMembership.find_or_create_by!(
              knowledge_cluster: cluster,
              record_type: "Location",
              record_id: location.id
            ) do |membership|
              # Calculate simple similarity score based on keyword matches
              membership.similarity_score = calculate_keyword_similarity(location, keywords)
            end
          rescue ActiveRecord::RecordInvalid
            # Skip duplicates
          end

          # Update representative IDs
          top_members = cluster.cluster_memberships
                               .by_similarity
                               .limit(5)
                               .pluck(:record_id)

          cluster.update!(
            representative_ids: top_members,
            member_count: cluster.cluster_memberships.count
          )
        end

        def calculate_keyword_similarity(location, keywords)
          text = "#{location.name} #{location.description}".downcase
          matches = keywords.count { |k| text.include?(k.downcase) }
          matches.to_f / keywords.size
        end
      end
    end
  end
end
