# frozen_string_literal: true

require_relative "executors"
require_relative "llm_helper"

module Platform
  module DSL
    # Executor - Izvršava DSL AST
    #
    # Modular architecture:
    # - Core executor delegates to specialized modules
    # - Each module handles one domain
    #
    # Modules:
    # - Schema: stats, describe, health
    # - TableQuery: dynamic queries on tables
    # - Infrastructure: system health, queue status, logs
    # - Prompts: prompt management, improvement, prompt actions
    # - Content: mutations, generation, audio
    # - Curator: proposals, applications, approval, curator management
    # - Knowledge: summaries, clusters
    # - External: external APIs, code introspection
    #
    class Executor
      extend LLMHelper
      # Re-export TABLE_MAP for backwards compatibility
      TABLE_MAP = Executors::TableQuery::TABLE_MAP

      class << self
        def execute(ast)
          case ast[:type]
          # Schema queries
          when :schema_query
            Executors::Schema.execute(ast)

          # Table queries
          when :table_query
            Executors::TableQuery.execute(ast)

          # Infrastructure queries
          when :infrastructure_query
            Executors::Infrastructure.execute_infrastructure(ast)
          when :logs_query
            Executors::Infrastructure.execute_logs(ast)

          # Prompts queries
          when :prompts_query
            Executors::Prompts.execute_prompts_query(ast)
          when :improvement
            Executors::Prompts.execute_improvement(ast)
          when :prompt_action
            Executors::Prompts.execute_prompt_action(ast)

          # Content queries (mutations, generation, audio)
          when :mutation
            Executors::Content.execute_mutation(ast)
          when :generation
            Executors::Content.execute_generation(ast)
          when :audio
            Executors::Content.execute_audio(ast)

          # Curator queries
          when :proposals_query
            Executors::Curator.execute_proposals_query(ast)
          when :applications_query
            Executors::Curator.execute_applications_query(ast)
          when :approval
            Executors::Curator.execute_approval(ast)
          when :curators_query
            Executors::Curator.execute_curators_query(ast)
          when :curator_management
            Executors::Curator.execute_curator_management(ast)

          # Knowledge queries
          when :summaries_query
            Executors::Knowledge.execute_summaries_query(ast)
          when :clusters_query
            Executors::Knowledge.execute_clusters_query(ast)

          # External queries
          when :external_query
            Executors::External.execute_external_query(ast)
          when :code_query
            Executors::External.execute_code_query(ast)

          # Quality queries
          when :quality_query
            Executors::Quality.execute_quality_query(ast)

          # Validation queries
          when :validation
            Executors::Quality.execute_validation(ast)

          else
            raise ExecutionError, "Nepoznat tip query-ja: #{ast[:type]}"
          end
        end

        # Legacy helper methods for backwards compatibility
        def resolve_model(table_name)
          Executors::TableQuery.resolve_model(table_name)
        end

        # generate_with_llm is provided by LLMHelper

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

        # Content delegations
        def execute_mutation(ast) = Executors::Content.execute_mutation(ast)
        def execute_generation(ast) = Executors::Content.execute_generation(ast)
        def execute_audio(ast) = Executors::Content.execute_audio(ast)
        def find_voice_id(name) = Executors::Content.send(:find_voice_id, name)
        def is_location_table?(table) = Executors::Content.send(:is_location_table?, table)
        def is_experience_table?(table) = Executors::Content.send(:is_experience_table?, table)
        def validate_mutation_data!(table, data, action) = Executors::Content.send(:validate_mutation_data!, table, data, action)
        def find_record_for_mutation(model, filters) = Executors::Content.send(:find_record_for_mutation, model, filters)
        def format_created_record(record) = Executors::Content.send(:format_created_record, record)

        # Curator delegations
        def execute_proposals_query(ast) = Executors::Curator.execute_proposals_query(ast)
        def execute_applications_query(ast) = Executors::Curator.execute_applications_query(ast)
        def execute_approval(ast) = Executors::Curator.execute_approval(ast)
        def execute_curators_query(ast) = Executors::Curator.execute_curators_query(ast)
        def execute_curator_management(ast) = Executors::Curator.execute_curator_management(ast)
        def list_proposals(filters) = Executors::Curator.send(:list_proposals, filters)
        def list_applications(filters) = Executors::Curator.send(:list_applications, filters)
        def list_curators(filters) = Executors::Curator.send(:list_curators, filters)

        # Knowledge delegations
        def execute_summaries_query(ast) = Executors::Knowledge.execute_summaries_query(ast)
        def execute_clusters_query(ast) = Executors::Knowledge.execute_clusters_query(ast)
        def list_summaries(filters) = Executors::Knowledge.send(:list_summaries, filters)
        def list_clusters(filters) = Executors::Knowledge.send(:list_clusters, filters)
        def extract_dimension_and_value(filters) = Executors::Knowledge.send(:extract_dimension_and_value, filters)
        def semantic_search_clusters(query) = Executors::Knowledge.send(:semantic_search_clusters, query)
        def refresh_clusters(filters) = Executors::Knowledge.send(:refresh_clusters, filters)

        # External delegations
        def execute_external_query(ast) = Executors::External.execute_external_query(ast)
        def execute_code_query(ast) = Executors::External.execute_code_query(ast)
        def validate_location(filters) = Executors::External.send(:validate_location, filters)
        def check_duplicate(filters) = Executors::External.send(:check_duplicate, filters)
        def geocode_address(filters) = Executors::External.send(:geocode_address, filters)
        def reverse_geocode_coords(filters) = Executors::External.send(:reverse_geocode_coords, filters)
        def search_pois(filters, args) = Executors::External.send(:search_pois, filters, args)
        def get_city_coordinates(city) = Executors::External.send(:get_city_coordinates, city)
        def haversine_distance(lat1, lng1, lat2, lng2) = Executors::External.send(:haversine_distance, lat1, lng1, lat2, lng2)
        def to_radians(degrees) = Executors::External.send(:to_radians, degrees)
        def geoapify_service = Executors::External.send(:geoapify_service)
        def format_poi_result(place) = Executors::External.send(:format_poi_result, place)

        # Schema query execution for tests
        def execute_schema_query(ast) = Executors::Schema.execute(ast)
      end
    end
  end
end
