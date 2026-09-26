class NibbleCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_users" do |t|
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
      t.index [ "email_address" ], name: "index_nibble_users_on_email_address", unique: true
    end
    add_foreign_key "drafts", "nibble_users", column: "author_id"
    add_foreign_key "entries", "nibble_users", column: "author_id"
    add_foreign_key "entries", "nibble_users", column: "created_by_id"
    add_foreign_key "entries", "nibble_users", column: "updated_by_id"
    add_foreign_key "nibble_api_tokens", "nibble_users", column: "created_by_id", on_delete: :nullify
    add_foreign_key "nibble_sessions", "nibble_users", column: "user_id"
    add_foreign_key "nibble_user_credentials", "nibble_users", column: "user_id", on_delete: :cascade
    add_foreign_key "nibble_user_roles", "nibble_users", column: "user_id", on_delete: :cascade
    add_foreign_key "revisions", "nibble_users", column: "actor_id"
  end
end
