# frozen_string_literal: true

module Platform
  module DSL
    module Executors
      # Knowledge executor - handles summaries and clusters queries
      #
      # Query types:
      # - summaries_query: Knowledge Layer 1 - summaries by dimension
      # - clusters_query: Knowledge Layer 2 - semantic clusters
      #
      module Knowledge
        class << self
          # Execute summaries query (Knowledge Layer 1)
          def execute_summaries_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :list
              list_summaries(filters)
            when :show
              show_summary(filters)
            when :issues
              show_issues(filters)
            when :refresh
              refresh_summaries(filters)
            else
              raise ExecutionError, "Nepoznata summaries operacija: #{operation&.dig(:name)}"
            end
          end

          # Execute clusters query (Knowledge Layer 2)
          def execute_clusters_query(ast)
            filters = ast[:filters] || {}
            operation = ast[:operations]&.first

            case operation&.dig(:name)
            when :list
              list_clusters(filters)
            when :show
              show_cluster(filters)
            when :semantic
              semantic_search_clusters(operation[:args]&.first)
            when :members
              show_cluster_members(filters)
            when :refresh
              refresh_clusters(filters)
            else
              raise ExecutionError, "Nepoznata clusters operacija: #{operation&.dig(:name)}"
            end
          end

          private

          # ===================
          # Summaries methods
          # ===================

          def list_summaries(filters)
            dimension = filters[:dimension] || filters[:city] && "city" || filters[:category] && "category"

            if dimension
              KnowledgeSummary.for_dimension(dimension).map(&:to_short_format)
            else
              {
                cities: KnowledgeSummary.cities,
                categories: KnowledgeSummary.categories,
                total: KnowledgeSummary.count,
                with_issues: KnowledgeSummary.with_issues.count
              }
            end
          end

          def show_summary(filters)
            dimension, value = extract_dimension_and_value(filters)

            unless dimension && value
              raise ExecutionError, "Potreban filter: city, category, ili region"
            end

            summary = Platform::Knowledge::LayerOne.get_summary(dimension, value)

            if summary
              {
                dimension: summary.dimension,
                value: summary.dimension_value,
                summary: summary.summary,
                stats: summary.stats,
                issues: summary.issues,
                patterns: summary.patterns,
                source_count: summary.source_count,
                generated_at: summary.generated_at&.iso8601
              }
            else
              raise ExecutionError, "Summary za #{dimension}=#{value} ne postoji"
            end
          end

          def show_issues(filters)
            dimension, value = extract_dimension_and_value(filters)

            if dimension && value
              summary = KnowledgeSummary.for_dimension_value(dimension, value)
              return [] unless summary

              summary.issues || []
            else
              KnowledgeSummary.with_issues.map do |s|
                {
                  dimension: s.dimension,
                  value: s.dimension_value,
                  issues: s.issues,
                  issues_count: s.issues_count
                }
              end
            end
          end

          def refresh_summaries(filters)
            dimension, value = extract_dimension_and_value(filters)

            if dimension && value
              summary = Platform::Knowledge::LayerOne.generate_summary(dimension, value)
              "Refreshed: #{summary&.to_short_format || 'failed'}"
            elsif dimension
              Platform::Knowledge::LayerOne.refresh_dimension(dimension)
              "Refreshed all #{dimension} summaries"
            else
              Platform::SummaryGenerationJob.perform_later
              "Queued full summary refresh"
            end
          end

          def extract_dimension_and_value(filters)
            if filters[:city]
              ["city", filters[:city]]
            elsif filters[:category]
              ["category", filters[:category]]
            elsif filters[:region]
              ["region", filters[:region]]
            elsif filters[:dimension] && filters[:value]
              [filters[:dimension], filters[:value]]
            else
              [nil, nil]
            end
          end

          # ===================
          # Clusters methods
          # ===================

          def list_clusters(filters)
            clusters = KnowledgeCluster.by_member_count

            if filters[:min_members]
              clusters = clusters.where("member_count >= ?", filters[:min_members])
            end

            {
              clusters: clusters.map do |c|
                {
                  slug: c.slug,
                  name: c.name,
                  member_count: c.member_count,
                  summary: c.summary&.truncate(100)
                }
              end,
              total: clusters.count,
              semantic_search_available: KnowledgeCluster.semantic_search_available?
            }
          end

          def show_cluster(filters)
            slug = filters[:id] || filters[:slug]
            raise ExecutionError, "Potreban filter: id ili slug" unless slug

            cluster = Platform::Knowledge::LayerTwo.get_cluster(slug)
            raise ExecutionError, "Cluster '#{slug}' ne postoji" unless cluster

            {
              slug: cluster.slug,
              name: cluster.name,
              summary: cluster.summary,
              member_count: cluster.member_count,
              stats: cluster.stats,
              representative_ids: cluster.representative_ids,
              created_at: cluster.created_at.iso8601
            }
          end

          def semantic_search_clusters(query)
            raise ExecutionError, "Semantic search zahtijeva upit" unless query

            unless KnowledgeCluster.semantic_search_available?
              return {
                error: "Semantic search nije dostupan (pgvector nije instaliran)",
                fallback: list_clusters({})
              }
            end

            results = Platform::Knowledge::LayerTwo.semantic_search(query, limit: 5)

            {
              query: query,
              results: results.map do |c|
                {
                  slug: c.slug,
                  name: c.name,
                  member_count: c.member_count,
                  summary: c.summary&.truncate(100)
                }
              end
            }
          end

          def show_cluster_members(filters)
            slug = filters[:id] || filters[:slug]
            raise ExecutionError, "Potreban filter: id ili slug" unless slug

            cluster = KnowledgeCluster.find_by(slug: slug)
            raise ExecutionError, "Cluster '#{slug}' ne postoji" unless cluster

            limit = filters[:limit] || 10

            memberships = cluster.cluster_memberships
                                 .by_similarity
                                 .limit(limit)
                                 .includes(:record)

            {
              cluster: cluster.name,
              members: memberships.map do |m|
                {
                  type: m.record_type,
                  id: m.record_id,
                  name: m.record.respond_to?(:name) ? m.record.name : m.record.try(:title),
                  similarity: m.similarity_score&.round(3)
                }
              end
            }
          end

          def refresh_clusters(filters)
            if filters[:regenerate]
              Platform::ClusterGenerationJob.perform_later(regenerate: true)
              "Queued full cluster regeneration"
            else
              Platform::ClusterGenerationJob.perform_later
              "Queued cluster membership refresh"
            end
          end
        end
      end
    end
  end
end
