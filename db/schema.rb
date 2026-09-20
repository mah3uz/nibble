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

ActiveRecord::Schema[8.1].define(version: 2026_09_20_103100) do
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

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "prefix", null: false
    t.datetime "revoked_at"
    t.json "scopes", default: [], null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_api_tokens_on_created_by_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "asset_folders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "parent_id"
    t.string "path", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_asset_folders_on_parent_id"
    t.index ["path"], name: "index_asset_folders_on_path", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.string "alt"
    t.integer "blob_id", null: false
    t.text "caption"
    t.datetime "created_at", null: false
    t.string "credit"
    t.json "data", default: {}, null: false
    t.datetime "deleted_at"
    t.float "duration"
    t.json "edits", default: {}, null: false
    t.string "filename", null: false
    t.float "focal_x"
    t.float "focal_y"
    t.float "focal_zoom", default: 1.0, null: false
    t.string "folder", default: "", null: false
    t.integer "height"
    t.string "kind", default: "file", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "mime", null: false
    t.bigint "size", null: false
    t.json "tags", default: [], null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.integer "width"
    t.index ["blob_id"], name: "index_assets_on_blob_id"
    t.index ["deleted_at"], name: "index_assets_on_deleted_at"
    t.index ["folder", "filename"], name: "index_assets_on_folder_and_filename"
    t.index ["kind", "deleted_at"], name: "index_assets_on_kind_and_deleted_at"
    t.index ["uuid"], name: "index_assets_on_uuid", unique: true
  end

  create_table "audit_log", force: :cascade do |t|
    t.string "action", null: false
    t.integer "actor_id"
    t.string "actor_type"
    t.json "changeset", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "ip"
    t.integer "subject_id"
    t.string "subject_type"
    t.index ["actor_type", "actor_id"], name: "index_audit_log_on_actor"
    t.index ["created_at"], name: "index_audit_log_on_created_at"
    t.index ["subject_type", "subject_id"], name: "index_audit_log_on_subject"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.json "mentions", default: [], null: false
    t.integer "parent_id"
    t.datetime "resolved_at"
    t.integer "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["subject_type", "subject_id", "created_at"], name: "index_comments_on_subject"
  end

  create_table "content_migrations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "ran_at", null: false
    t.json "results", default: [], null: false
    t.index ["name"], name: "index_content_migrations_on_name", unique: true
  end

  create_table "drafts", force: :cascade do |t|
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.string "workflow_status"
    t.index ["author_id"], name: "index_drafts_on_author_id"
    t.index ["record_type", "record_id"], name: "index_drafts_on_record", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.integer "author_id"
    t.string "blueprint", null: false
    t.string "collection", null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.json "data", default: {}, null: false
    t.datetime "deleted_at"
    t.string "locale", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "origin_id"
    t.integer "parent_id"
    t.integer "position"
    t.datetime "published_at"
    t.string "slug"
    t.string "status", default: "draft", null: false
    t.string "template"
    t.string "title"
    t.datetime "unpublish_at"
    t.datetime "updated_at", null: false
    t.integer "updated_by_id"
    t.string "uri"
    t.string "uuid", null: false
    t.index ["author_id"], name: "index_entries_on_author_id"
    t.index ["collection", "locale", "parent_id", "slug"], name: "index_entries_on_collection_and_locale_and_parent_id_and_slug", unique: true, where: "deleted_at IS NULL"
    t.index ["collection", "locale", "status", "published_at"], name: "idx_on_collection_locale_status_published_at_43657fb133"
    t.index ["collection", "parent_id", "position"], name: "index_entries_on_collection_and_parent_id_and_position"
    t.index ["collection", "published_at"], name: "index_entries_on_collection_and_published_at"
    t.index ["created_by_id"], name: "index_entries_on_created_by_id"
    t.index ["deleted_at"], name: "index_entries_on_deleted_at"
    t.index ["origin_id"], name: "index_entries_on_origin_id"
    t.index ["parent_id"], name: "index_entries_on_parent_id"
    t.index ["updated_by_id"], name: "index_entries_on_updated_by_id"
    t.index ["uri"], name: "index_entries_on_uri", unique: true, where: "deleted_at IS NULL"
    t.index ["uuid"], name: "index_entries_on_uuid", unique: true
  end

  create_table "events_outbox", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "dispatched_at"
    t.string "name", null: false
    t.json "payload", default: {}, null: false
    t.index ["dispatched_at"], name: "index_events_outbox_on_dispatched_at"
  end

  create_table "form_submissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.json "deliveries", default: [], null: false
    t.string "form", null: false
    t.string "ip_hash"
    t.string "locale"
    t.datetime "read_at"
    t.string "status", default: "received", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["form", "created_at"], name: "index_form_submissions_on_form_and_created_at"
    t.index ["form", "status"], name: "index_form_submissions_on_form_and_status"
  end

  create_table "global_sets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.string "handle", null: false
    t.string "locale", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "origin_id"
    t.datetime "updated_at", null: false
    t.index ["handle", "locale"], name: "index_global_sets_on_handle_and_locale", unique: true
    t.index ["origin_id"], name: "index_global_sets_on_origin_id"
  end

  create_table "navigation_trees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "handle", null: false
    t.string "locale", null: false
    t.integer "lock_version", default: 0, null: false
    t.json "tree", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["handle", "locale"], name: "index_navigation_trees_on_handle_and_locale", unique: true
  end

  create_table "not_found_log", force: :cascade do |t|
    t.datetime "first_seen_at", null: false
    t.integer "hits", default: 0, null: false
    t.datetime "last_seen_at", null: false
    t.string "path", null: false
    t.string "referrer"
    t.index ["hits"], name: "index_not_found_log_on_hits"
    t.index ["path"], name: "index_not_found_log_on_path", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.string "kind", null: false
    t.datetime "read_at"
    t.integer "subject_id"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_and_state"
  end

  create_table "outbound_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "error"
    t.string "method", null: false
    t.integer "owner_id"
    t.string "owner_type"
    t.string "purpose", null: false
    t.text "request_body"
    t.json "request_headers", default: {}, null: false
    t.text "response_body"
    t.integer "status"
    t.string "url", null: false
    t.index ["created_at"], name: "index_outbound_requests_on_created_at"
    t.index ["owner_type", "owner_id", "created_at"], name: "idx_on_owner_type_owner_id_created_at_9cf9274ad2"
  end

  create_table "redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "from", null: false
    t.integer "hits", default: 0, null: false
    t.datetime "last_hit_at"
    t.string "source", default: "manual", null: false
    t.integer "status", default: 301, null: false
    t.string "to", null: false
    t.datetime "updated_at", null: false
    t.index ["from"], name: "index_redirects_on_from", unique: true
    t.index ["to"], name: "index_redirects_on_to"
  end

  create_table "relations", force: :cascade do |t|
    t.string "field", null: false
    t.string "locale", null: false
    t.integer "position", default: 0, null: false
    t.integer "source_id", null: false
    t.string "source_type", null: false
    t.integer "target_id", null: false
    t.string "target_type", null: false
    t.index ["source_type", "source_id"], name: "index_relations_on_source"
    t.index ["target_type", "target_id"], name: "index_relations_on_target"
  end

  create_table "revisions", force: :cascade do |t|
    t.integer "actor_id"
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.string "kind", null: false
    t.string "message"
    t.integer "number", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["actor_id"], name: "index_revisions_on_actor_id"
    t.index ["record_type", "record_id", "number"], name: "index_revisions_on_record_type_and_record_id_and_number", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.json "abilities", default: [], null: false
    t.datetime "created_at", null: false
    t.string "handle", null: false
    t.boolean "require_2fa", default: false, null: false
    t.boolean "superuser", default: false, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_roles_on_handle", unique: true
  end

  create_table "schema_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "digest", null: false
    t.json "types", default: {}, null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "elevated_at"
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sign_in_attempts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_digest", null: false
    t.string "ip"
    t.string "kind", default: "password", null: false
    t.index ["email_digest", "created_at"], name: "index_sign_in_attempts_on_email_digest_and_created_at"
  end

  create_table "terms", force: :cascade do |t|
    t.string "blueprint", null: false
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.datetime "deleted_at"
    t.string "locale", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "origin_id"
    t.string "slug", null: false
    t.string "taxonomy", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "uri"
    t.string "uuid", null: false
    t.index ["deleted_at"], name: "index_terms_on_deleted_at"
    t.index ["origin_id"], name: "index_terms_on_origin_id"
    t.index ["taxonomy", "locale", "slug"], name: "index_terms_on_taxonomy_and_locale_and_slug", unique: true, where: "deleted_at IS NULL"
    t.index ["uri"], name: "index_terms_on_uri"
    t.index ["uuid"], name: "index_terms_on_uuid", unique: true
  end

  create_table "user_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "provider", default: "webauthn", null: false
    t.text "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["external_id"], name: "index_user_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_user_credentials_on_user_id"
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "last_login_at"
    t.string "name", null: false
    t.string "password_digest", null: false
    t.json "preferences", default: {}, null: false
    t.json "recovery_codes", default: [], null: false
    t.datetime "totp_confirmed_at"
    t.datetime "totp_last_used_at"
    t.text "totp_secret_ciphertext"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "error"
    t.string "event", null: false
    t.integer "event_id"
    t.datetime "next_attempt_at"
    t.json "payload", default: {}, null: false
    t.integer "response_status"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "webhook_id", null: false
    t.index ["created_at"], name: "index_webhook_deliveries_on_created_at"
    t.index ["webhook_id", "created_at"], name: "index_webhook_deliveries_on_webhook_id_and_created_at"
    t.index ["webhook_id"], name: "index_webhook_deliveries_on_webhook_id"
  end

  create_table "webhooks", force: :cascade do |t|
    t.json "collections", default: [], null: false
    t.integer "consecutive_failures", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "disabled_reason"
    t.boolean "enabled", default: true, null: false
    t.json "events", default: [], null: false
    t.string "name", null: false
    t.text "secret_ciphertext", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
  end

  create_table "workflow_transitions", force: :cascade do |t|
    t.integer "actor_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "from", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.string "to", null: false
    t.index ["actor_id"], name: "index_workflow_transitions_on_actor_id"
    t.index ["record_type", "record_id"], name: "index_workflow_transitions_on_record"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "asset_folders", "asset_folders", column: "parent_id"
  add_foreign_key "assets", "active_storage_blobs", column: "blob_id"
  add_foreign_key "drafts", "users", column: "author_id"
  add_foreign_key "entries", "entries", column: "origin_id"
  add_foreign_key "entries", "entries", column: "parent_id"
  add_foreign_key "entries", "users", column: "author_id"
  add_foreign_key "entries", "users", column: "created_by_id"
  add_foreign_key "entries", "users", column: "updated_by_id"
  add_foreign_key "global_sets", "global_sets", column: "origin_id"
  add_foreign_key "revisions", "users", column: "actor_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "terms", "terms", column: "origin_id"
  add_foreign_key "user_credentials", "users", on_delete: :cascade
  add_foreign_key "user_roles", "roles", on_delete: :cascade
  add_foreign_key "user_roles", "users", on_delete: :cascade
  add_foreign_key "webhook_deliveries", "webhooks", on_delete: :cascade
  add_foreign_key "workflow_transitions", "users", column: "actor_id"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "search_index", "fts5", ["title", "body", "record_type UNINDEXED", "record_id UNINDEXED", "index_handle UNINDEXED", "locale UNINDEXED", "tokenize = 'porter unicode61 remove_diacritics 2'"]
  create_virtual_table "search_index_trigram", "fts5", ["title", "body", "record_type UNINDEXED", "record_id UNINDEXED", "index_handle UNINDEXED", "locale UNINDEXED", "tokenize = 'trigram remove_diacritics 1'"]
end
