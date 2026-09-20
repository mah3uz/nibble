class AddForeignKeys < ActiveRecord::Migration[8.1]
  def change
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
  end
end
