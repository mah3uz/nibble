class NibbleCreateApiTokens < ActiveRecord::Migration[8.1]
  def change
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
      t.index [ "created_by_id" ], name: "index_api_tokens_on_created_by_id"
      t.index [ "token_digest" ], name: "index_api_tokens_on_token_digest", unique: true
    end
  end
end
