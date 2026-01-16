# This file is auto-generated from the current state of the platform database.
# It contains the schema for Platform-related tables that use the platform database.
#
# The platform database supports pgvector for semantic search capabilities.

ActiveRecord::Schema[8.1].define(version: 2026_01_15_171026) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "cluster_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "knowledge_cluster_id", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.float "similarity_score"
    t.datetime "updated_at", null: false
    t.index ["knowledge_cluster_id", "record_type", "record_id"], name: "idx_cluster_memberships_unique", unique: true
    t.index ["knowledge_cluster_id"], name: "index_cluster_memberships_on_knowledge_cluster_id"
    t.index ["record_type", "record_id"], name: "index_cluster_memberships_on_record_type_and_record_id"
  end

  create_table "knowledge_clusters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1536
    t.integer "member_count", default: 0
    t.string "name", null: false
    t.jsonb "representative_ids", default: []
    t.string "slug", null: false
    t.jsonb "stats", default: {}
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_knowledge_clusters_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["slug"], name: "index_knowledge_clusters_on_slug", unique: true
  end

  create_table "knowledge_summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "dimension", null: false
    t.string "dimension_value", null: false
    t.datetime "generated_at"
    t.jsonb "issues", default: []
    t.jsonb "patterns", default: []
    t.integer "source_count", default: 0
    t.jsonb "stats", default: {}
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["dimension", "dimension_value"], name: "idx_summaries_dimension_value", unique: true
    t.index ["dimension"], name: "index_knowledge_summaries_on_dimension"
    t.index ["generated_at"], name: "index_knowledge_summaries_on_generated_at"
  end

  create_table "platform_audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "change_data", default: {}
    t.uuid "conversation_id"
    t.datetime "created_at", null: false
    t.bigint "record_id"
    t.string "record_type"
    t.string "triggered_by", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_platform_audit_logs_on_action"
    t.index ["conversation_id"], name: "index_platform_audit_logs_on_conversation_id"
    t.index ["record_type", "record_id"], name: "index_platform_audit_logs_on_record_type_and_record_id"
    t.index ["triggered_by"], name: "index_platform_audit_logs_on_triggered_by"
  end

  create_table "platform_conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.jsonb "messages", default: [], null: false
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_platform_conversations_on_status"
  end

  create_table "platform_statistics", force: :cascade do |t|
    t.datetime "computed_at"
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value", default: {}, null: false
    t.index ["key"], name: "index_platform_statistics_on_key", unique: true
  end

  create_table "prepared_prompts", force: :cascade do |t|
    t.text "analysis"
    t.text "content", null: false
    t.uuid "conversation_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "prompt_type", null: false
    t.string "severity"
    t.text "solution"
    t.string "status", default: "pending"
    t.string "target_file"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["prompt_type"], name: "index_prepared_prompts_on_prompt_type"
    t.index ["severity"], name: "index_prepared_prompts_on_severity"
    t.index ["status"], name: "index_prepared_prompts_on_status"
    t.index ["user_id"], name: "index_prepared_prompts_on_user_id"
  end

  add_foreign_key "cluster_memberships", "knowledge_clusters"
end
