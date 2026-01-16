# frozen_string_literal: true

require_relative "executors"

module Platform
  module DSL
    # Executor - Izvršava DSL AST
    #
    # Refactored architecture:
    # - Core executor delegates to specialized modules
    # - Each module handles one domain (schema, tables, infrastructure, prompts)
    # - Unused features archived in executors/future/
    #
    # Supported query types:
    # - schema_query: stats, describe, health
    # - table_query: dynamic queries on tables
    # - infrastructure_query: system health, queue status
    # - logs_query: audit logs, errors
    # - prompts_query: prompt management
    # - improvement: prepare fix/feature
    # - prompt_action: apply/reject prompts
    #
    # Archived (not currently used):
    # - summaries_query, clusters_query, external_query
    # - mutation, generation, audio
    # - proposals_query, applications_query, approval
    # - curators_query, curator_management, code_query
    #
    class Executor
      # Re-export TABLE_MAP for backwards compatibility
      TABLE_MAP = Executors::TableQuery::TABLE_MAP

      class << self
        def execute(ast)
          case ast[:type]
          # Active query types - delegated to modules
          when :schema_query
            Executors::Schema.execute(ast)
          when :table_query
            Executors::TableQuery.execute(ast)
          when :infrastructure_query
            Executors::Infrastructure.execute_infrastructure(ast)
          when :logs_query
            Executors::Infrastructure.execute_logs(ast)
          when :prompts_query
            Executors::Prompts.execute_prompts_query(ast)
          when :improvement
            Executors::Prompts.execute_improvement(ast)
          when :prompt_action
            Executors::Prompts.execute_prompt_action(ast)

          # Archived query types - return not available message
          when :summaries_query
            not_available(:summaries_query, "Knowledge summaries queries")
          when :clusters_query
            not_available(:clusters_query, "Knowledge cluster queries")
          when :external_query
            not_available(:external_query, "External API queries (Geoapify)")
          when :mutation
            not_available(:mutation, "Data mutations (create/update/delete)")
          when :generation
            not_available(:generation, "AI content generation")
          when :audio
            not_available(:audio, "Audio synthesis")
          when :proposals_query
            not_available(:proposals_query, "Curator proposal queries")
          when :applications_query
            not_available(:applications_query, "Curator application queries")
          when :approval
            not_available(:approval, "Content approval actions")
          when :curators_query
            not_available(:curators_query, "Curator management queries")
          when :curator_management
            not_available(:curator_management, "Curator management actions")
          when :code_query
            not_available(:code_query, "Code introspection queries")
          else
            raise ExecutionError, "Nepoznat tip query-ja: #{ast[:type]}"
          end
        end

        # Legacy helper methods for backwards compatibility
        def resolve_model(table_name)
          Executors::TableQuery.resolve_model(table_name)
        end

        # Helper to generate not available message
        def not_available(query_type, description)
          {
            error: "not_available",
            query_type: query_type,
            message: "#{description} nisu trenutno dostupni.",
            hint: "Ova funkcionalnost je planirana za buduće verzije. Pogledajte .claude/planning/IMPLEMENTATION.md za roadmap."
          }
        end

        # For backwards compatibility with tests that stub generate_with_llm
        def generate_with_llm(prompt)
          chat = RubyLLM.chat(model: "claude-sonnet-4-20250514")
          response = chat.ask(prompt)
          response.content.strip
        rescue => e
          raise ExecutionError, "LLM greška: #{e.message}"
        end

        private

        # ==========================================================
        # Delegation methods for backwards compatibility with tests
        # These methods are private and called via .send() in tests
        # ==========================================================

        # Schema delegations
        def build_stats = Executors::Schema.send(:build_stats)
        def build_stats_directly = Executors::Schema.send(:build_stats_directly)
        def format_cached_stats(data) = Executors::Schema.send(:format_cached_stats, data)
        def check_database_health = Executors::Schema.send(:check_database_health)
        def check_api_keys = Executors::Schema.send(:check_api_keys)
        def check_queue_health = Executors::Schema.send(:check_queue_health)
        def check_storage_health = Executors::Schema.send(:check_storage_health)
        def describe_table(table_name) = Executors::Schema.send(:describe_table, table_name)

        # TableQuery delegations
        def apply_filters(model, filters) = Executors::TableQuery.send(:apply_filters, model, filters)
        def apply_filter(scope, key, value) = Executors::TableQuery.send(:apply_filter, scope, key, value)
        def apply_operations(scope, ops) = Executors::TableQuery.send(:apply_operations, scope, ops)
        def apply_operation(scope, op) = Executors::TableQuery.send(:apply_operation, scope, op)
        def apply_aggregate(scope, op) = Executors::TableQuery.send(:apply_aggregate, scope, op)
        def apply_where_condition(scope, cond) = Executors::TableQuery.send(:apply_where_condition, scope, cond)
        def format_record(record) = Executors::TableQuery.send(:format_record, record)

        # Infrastructure delegations
        def show_errors(filters) = Executors::Infrastructure.send(:show_errors, filters)
        def show_slow_queries(filters) = Executors::Infrastructure.send(:show_slow_queries, filters)
        def show_recent_logs(filters) = Executors::Infrastructure.send(:show_recent_logs, filters)
        def show_audit_logs(filters) = Executors::Infrastructure.send(:show_audit_logs, filters)
        def show_dsl_logs(filters) = Executors::Infrastructure.send(:show_dsl_logs, filters)
        def logs_summary(filters) = Executors::Infrastructure.send(:logs_summary, filters)
        def queue_status = Executors::Infrastructure.send(:queue_status)
        def infrastructure_health = Executors::Infrastructure.send(:infrastructure_health)

        # Prompts delegations
        def list_prompts(filters) = Executors::Prompts.send(:list_prompts, filters)
        def show_prompt(filters) = Executors::Prompts.send(:show_prompt, filters)
        def count_prompts(filters) = Executors::Prompts.send(:count_prompts, filters)

        # Schema query execution for tests
        def execute_schema_query(ast) = Executors::Schema.execute(ast)
      end
    end
  end
end
