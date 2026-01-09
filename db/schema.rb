# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_09_193210) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_generations", force: :cascade do |t|
    t.string "city_name"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "experiences_created", default: 0
    t.string "generation_type", null: false
    t.integer "locations_created", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["city_name"], name: "index_ai_generations_on_city_name"
    t.index ["generation_type"], name: "index_ai_generations_on_generation_type"
    t.index ["status"], name: "index_ai_generations_on_status"
  end

  create_table "audio_tours", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "duration"
    t.string "locale", default: "bs", null: false
    t.bigint "location_id", null: false
    t.jsonb "metadata", default: {}
    t.text "script"
    t.string "tts_provider"
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.string "voice_id"
    t.integer "word_count"
    t.index ["locale"], name: "index_audio_tours_on_locale"
    t.index ["location_id", "locale"], name: "index_audio_tours_on_location_id_and_locale", unique: true
    t.index ["location_id"], name: "index_audio_tours_on_location_id"
    t.index ["uuid"], name: "index_audio_tours_on_uuid", unique: true
  end

  create_table "browses", force: :cascade do |t|
    t.boolean "ai_generated", default: true, null: false
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0"
    t.bigint "browsable_id", null: false
    t.string "browsable_subtype"
    t.string "browsable_type", null: false
    t.integer "budget"
    t.jsonb "category_keys", default: []
    t.string "city_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.integer "reviews_count", default: 0
    t.virtual "searchable", type: :tsvector, as: "(setweight(to_tsvector('simple'::regconfig, (COALESCE(title, ''::character varying))::text), 'A'::\"char\") || setweight(to_tsvector('simple'::regconfig, COALESCE(description, ''::text)), 'B'::\"char\"))", stored: true
    t.jsonb "seasons", default: []
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_generated"], name: "index_browses_on_ai_generated"
    t.index ["average_rating"], name: "index_browses_on_average_rating"
    t.index ["browsable_subtype"], name: "index_browses_on_browsable_subtype"
    t.index ["browsable_type", "browsable_id"], name: "index_browses_on_browsable"
    t.index ["browsable_type", "browsable_id"], name: "index_browses_on_browsable_type_and_browsable_id", unique: true
    t.index ["browsable_type"], name: "index_browses_on_browsable_type"
    t.index ["budget"], name: "index_browses_on_budget"
    t.index ["category_keys"], name: "index_browses_on_category_keys", using: :gin
    t.index ["city_name"], name: "index_browses_on_city_name"
    t.index ["lat", "lng"], name: "index_browses_on_lat_and_lng"
    t.index ["reviews_count"], name: "index_browses_on_reviews_count"
    t.index ["searchable"], name: "index_browses_on_searchable", using: :gin
    t.index ["seasons"], name: "index_browses_on_seasons", using: :gin
  end

  create_table "content_change_contributions", force: :cascade do |t|
    t.bigint "content_change_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.jsonb "proposed_data", default: {}
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["content_change_id", "user_id"], name: "idx_contributions_unique_user_per_change", unique: true
    t.index ["content_change_id"], name: "index_content_change_contributions_on_content_change_id"
    t.index ["user_id"], name: "index_content_change_contributions_on_user_id"
  end

  create_table "content_changes", force: :cascade do |t|
    t.text "admin_notes"
    t.integer "change_type", default: 0, null: false
    t.string "changeable_class"
    t.bigint "changeable_id"
    t.string "changeable_type"
    t.datetime "created_at", null: false
    t.jsonb "original_data", default: {}
    t.jsonb "proposed_data", default: {}
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["change_type"], name: "index_content_changes_on_change_type"
    t.index ["changeable_type", "changeable_id", "status"], name: "idx_content_changes_on_changeable_and_status"
    t.index ["changeable_type", "changeable_id"], name: "idx_unique_pending_proposal_per_resource", unique: true, where: "((status = 0) AND (changeable_id IS NOT NULL))"
    t.index ["changeable_type", "changeable_id"], name: "index_content_changes_on_changeable"
    t.index ["reviewed_by_id"], name: "index_content_changes_on_reviewed_by_id"
    t.index ["status"], name: "index_content_changes_on_status"
    t.index ["user_id", "status"], name: "index_content_changes_on_user_id_and_status"
    t.index ["user_id"], name: "index_content_changes_on_user_id"
  end

  create_table "curator_activities", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}
    t.bigint "recordable_id"
    t.string "recordable_type"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["action", "created_at"], name: "index_curator_activities_on_action_and_created_at"
    t.index ["created_at"], name: "index_curator_activities_on_created_at"
    t.index ["recordable_type", "recordable_id"], name: "index_curator_activities_on_recordable"
    t.index ["user_id", "created_at"], name: "index_curator_activities_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_curator_activities_on_user_id"
  end

  create_table "curator_applications", force: :cascade do |t|
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.text "experience"
    t.text "motivation", null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["reviewed_by_id"], name: "index_curator_applications_on_reviewed_by_id"
    t.index ["status"], name: "index_curator_applications_on_status"
    t.index ["user_id", "status"], name: "index_curator_applications_on_user_id_and_status"
    t.index ["user_id"], name: "index_curator_applications_on_user_id"
    t.index ["uuid"], name: "index_curator_applications_on_uuid", unique: true
  end

  create_table "curator_reviews", force: :cascade do |t|
    t.text "comment", null: false
    t.bigint "content_change_id", null: false
    t.datetime "created_at", null: false
    t.integer "recommendation", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["content_change_id", "created_at"], name: "index_curator_reviews_on_content_change_id_and_created_at"
    t.index ["content_change_id"], name: "index_curator_reviews_on_content_change_id"
    t.index ["user_id"], name: "index_curator_reviews_on_user_id"
  end

  create_table "experience_categories", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.integer "default_duration", default: 180
    t.text "description"
    t.string "icon"
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["active"], name: "index_experience_categories_on_active"
    t.index ["key"], name: "index_experience_categories_on_key", unique: true
    t.index ["position"], name: "index_experience_categories_on_position"
    t.index ["uuid"], name: "index_experience_categories_on_uuid", unique: true
  end

  create_table "experience_category_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "experience_category_id", null: false
    t.bigint "experience_type_id", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.index ["experience_category_id", "experience_type_id"], name: "idx_category_types_uniqueness", unique: true
    t.index ["experience_category_id"], name: "index_experience_category_types_on_experience_category_id"
    t.index ["experience_type_id"], name: "index_experience_category_types_on_experience_type_id"
  end

  create_table "experience_locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "experience_id", null: false
    t.bigint "location_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["experience_id", "location_id"], name: "index_experience_locations_on_experience_id_and_location_id", unique: true
    t.index ["experience_id", "position"], name: "index_experience_locations_on_experience_id_and_position"
    t.index ["experience_id"], name: "index_experience_locations_on_experience_id"
    t.index ["location_id"], name: "index_experience_locations_on_location_id"
  end

  create_table "experience_types", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["active"], name: "index_experience_types_on_active"
    t.index ["key"], name: "index_experience_types_on_key", unique: true
    t.index ["position"], name: "index_experience_types_on_position"
    t.index ["uuid"], name: "index_experience_types_on_uuid", unique: true
  end

  create_table "experiences", force: :cascade do |t|
    t.boolean "ai_generated", default: true, null: false
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0"
    t.string "contact_email"
    t.string "contact_name"
    t.string "contact_phone"
    t.string "contact_website"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "estimated_duration"
    t.bigint "experience_category_id"
    t.boolean "needs_ai_regeneration", default: false, null: false
    t.integer "reviews_count", default: 0
    t.jsonb "seasons", default: []
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["ai_generated"], name: "index_experiences_on_ai_generated"
    t.index ["average_rating"], name: "index_experiences_on_average_rating"
    t.index ["experience_category_id"], name: "index_experiences_on_experience_category_id"
    t.index ["needs_ai_regeneration"], name: "index_experiences_on_needs_ai_regeneration", where: "(needs_ai_regeneration = true)"
    t.index ["reviews_count"], name: "index_experiences_on_reviews_count"
    t.index ["seasons"], name: "index_experiences_on_seasons", using: :gin
    t.index ["title"], name: "index_experiences_on_title"
    t.index ["uuid"], name: "index_experiences_on_uuid", unique: true
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "locales", force: :cascade do |t|
    t.boolean "active", default: true
    t.boolean "ai_supported", default: true
    t.string "code", limit: 10, null: false
    t.datetime "created_at", null: false
    t.string "flag_emoji"
    t.string "name", null: false
    t.string "native_name"
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_locales_on_active"
    t.index ["code"], name: "index_locales_on_code", unique: true
    t.index ["position"], name: "index_locales_on_position"
  end

  create_table "location_categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["active"], name: "index_location_categories_on_active"
    t.index ["key"], name: "index_location_categories_on_key", unique: true
    t.index ["position"], name: "index_location_categories_on_position"
    t.index ["uuid"], name: "index_location_categories_on_uuid", unique: true
  end

  create_table "location_category_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "location_category_id", null: false
    t.bigint "location_id", null: false
    t.boolean "primary", default: false
    t.datetime "updated_at", null: false
    t.index ["location_category_id"], name: "index_location_category_assignments_on_location_category_id"
    t.index ["location_id", "location_category_id"], name: "idx_loc_cat_assignments_unique", unique: true
    t.index ["location_id"], name: "index_location_category_assignments_on_location_id"
  end

  create_table "location_experience_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "experience_type_id", null: false
    t.bigint "location_id", null: false
    t.datetime "updated_at", null: false
    t.index ["experience_type_id"], name: "index_location_experience_types_on_experience_type_id"
    t.index ["location_id", "experience_type_id"], name: "idx_location_experience_types_uniqueness", unique: true
    t.index ["location_id"], name: "index_location_experience_types_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.boolean "ai_generated", default: true, null: false
    t.jsonb "audio_tour_metadata"
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0"
    t.integer "budget", default: 0
    t.string "city"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email"
    t.text "historical_context"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.integer "location_type", default: 0
    t.string "name", null: false
    t.boolean "needs_ai_regeneration", default: false, null: false
    t.string "phone"
    t.integer "reviews_count", default: 0
    t.jsonb "seasons", default: [], null: false
    t.jsonb "social_links", default: {}
    t.jsonb "suitable_experiences", default: []
    t.jsonb "tags", default: []
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.string "video_url"
    t.string "website"
    t.index ["ai_generated"], name: "index_locations_on_ai_generated"
    t.index ["average_rating"], name: "index_locations_on_average_rating"
    t.index ["budget"], name: "index_locations_on_budget"
    t.index ["city"], name: "index_locations_on_city"
    t.index ["lat", "lng"], name: "index_locations_on_coordinates_unique", unique: true, where: "((lat IS NOT NULL) AND (lng IS NOT NULL))"
    t.index ["location_type"], name: "index_locations_on_location_type"
    t.index ["name"], name: "index_locations_on_name"
    t.index ["needs_ai_regeneration"], name: "index_locations_on_needs_ai_regeneration", where: "(needs_ai_regeneration = true)"
    t.index ["reviews_count"], name: "index_locations_on_reviews_count"
    t.index ["seasons"], name: "index_locations_on_seasons", using: :gin
    t.index ["uuid"], name: "index_locations_on_uuid", unique: true
  end

  create_table "photo_suggestions", force: :cascade do |t|
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "location_id", null: false
    t.string "photo_url"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["location_id", "status"], name: "index_photo_suggestions_on_location_id_and_status"
    t.index ["location_id"], name: "index_photo_suggestions_on_location_id"
    t.index ["reviewed_by_id"], name: "index_photo_suggestions_on_reviewed_by_id"
    t.index ["user_id", "status"], name: "index_photo_suggestions_on_user_id_and_status"
    t.index ["user_id"], name: "index_photo_suggestions_on_user_id"
  end

  create_table "plan_experiences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_number", null: false
    t.bigint "experience_id", null: false
    t.bigint "plan_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["experience_id"], name: "index_plan_experiences_on_experience_id"
    t.index ["plan_id", "day_number", "position"], name: "index_plan_experiences_on_plan_id_and_day_number_and_position"
    t.index ["plan_id", "day_number"], name: "index_plan_experiences_on_plan_id_and_day_number"
    t.index ["plan_id", "experience_id", "day_number"], name: "index_plan_experiences_unique_per_day", unique: true
    t.index ["plan_id"], name: "index_plan_experiences_on_plan_id"
  end

  create_table "plans", force: :cascade do |t|
    t.boolean "ai_generated", default: true, null: false
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0"
    t.string "city_name"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "local_id"
    t.boolean "needs_ai_regeneration", default: false, null: false
    t.text "notes"
    t.jsonb "preferences", default: {}
    t.integer "reviews_count", default: 0
    t.date "start_date"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "uuid", limit: 36, null: false
    t.integer "visibility", default: 0, null: false
    t.index ["ai_generated"], name: "index_plans_on_ai_generated"
    t.index ["average_rating"], name: "index_plans_on_average_rating"
    t.index ["city_name"], name: "index_plans_on_city_name"
    t.index ["end_date"], name: "index_plans_on_end_date"
    t.index ["local_id"], name: "index_plans_on_local_id", unique: true, where: "(local_id IS NOT NULL)"
    t.index ["needs_ai_regeneration"], name: "index_plans_on_needs_ai_regeneration", where: "(needs_ai_regeneration = true)"
    t.index ["reviews_count"], name: "index_plans_on_reviews_count"
    t.index ["start_date", "end_date"], name: "index_plans_on_start_date_and_end_date"
    t.index ["start_date"], name: "index_plans_on_start_date"
    t.index ["user_id", "visibility"], name: "index_plans_on_user_id_and_visibility", where: "(user_id IS NOT NULL)"
    t.index ["user_id"], name: "index_plans_on_user_id"
    t.index ["uuid"], name: "index_plans_on_uuid", unique: true
    t.index ["visibility"], name: "index_plans_on_visibility"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "author_name"
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "rating", null: false
    t.bigint "reviewable_id", null: false
    t.string "reviewable_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "uuid", limit: 36, null: false
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["reviewable_type", "reviewable_id", "created_at"], name: "index_reviews_on_reviewable_and_created_at"
    t.index ["reviewable_type", "reviewable_id"], name: "index_reviews_on_reviewable"
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.index ["uuid"], name: "index_reviews_on_uuid", unique: true
  end

  create_table "settings", force: :cascade do |t|
    t.string "category", default: "general"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.string "value_type", default: "string"
    t.index ["category"], name: "index_settings_on_category"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "field_name", limit: 50, null: false
    t.string "locale", limit: 10, null: false
    t.bigint "translatable_id", null: false
    t.string "translatable_type", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["field_name"], name: "index_translations_on_field_name"
    t.index ["locale"], name: "index_translations_on_locale"
    t.index ["translatable_type", "translatable_id", "locale", "field_name"], name: "index_translations_uniqueness", unique: true
    t.index ["translatable_type", "translatable_id"], name: "index_translations_on_translatable"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "activity_count_reset_at"
    t.integer "activity_count_today", default: 0
    t.datetime "created_at", null: false
    t.string "password_digest", null: false
    t.string "spam_block_reason"
    t.datetime "spam_blocked_at"
    t.datetime "spam_blocked_until"
    t.jsonb "travel_profile_data", default: {}
    t.datetime "updated_at", null: false
    t.integer "user_type", default: 0, null: false
    t.string "username", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["user_type"], name: "index_users_on_user_type"
    t.index ["username"], name: "index_users_on_username", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audio_tours", "locations"
  add_foreign_key "content_change_contributions", "content_changes"
  add_foreign_key "content_change_contributions", "users"
  add_foreign_key "content_changes", "users"
  add_foreign_key "content_changes", "users", column: "reviewed_by_id"
  add_foreign_key "curator_activities", "users"
  add_foreign_key "curator_applications", "users"
  add_foreign_key "curator_applications", "users", column: "reviewed_by_id"
  add_foreign_key "curator_reviews", "content_changes"
  add_foreign_key "curator_reviews", "users"
  add_foreign_key "experience_category_types", "experience_categories"
  add_foreign_key "experience_category_types", "experience_types"
  add_foreign_key "experience_locations", "experiences"
  add_foreign_key "experience_locations", "locations"
  add_foreign_key "experiences", "experience_categories"
  add_foreign_key "location_category_assignments", "location_categories"
  add_foreign_key "location_category_assignments", "locations"
  add_foreign_key "location_experience_types", "experience_types"
  add_foreign_key "location_experience_types", "locations"
  add_foreign_key "photo_suggestions", "locations"
  add_foreign_key "photo_suggestions", "users"
  add_foreign_key "photo_suggestions", "users", column: "reviewed_by_id"
  add_foreign_key "plan_experiences", "experiences"
  add_foreign_key "plan_experiences", "plans"
  add_foreign_key "plans", "users"
  add_foreign_key "reviews", "users"
end
