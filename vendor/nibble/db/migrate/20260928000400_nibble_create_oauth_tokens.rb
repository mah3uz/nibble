class NibbleCreateOauthTokens < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_oauth_tokens" do |t|
      t.integer "grant_id", null: false
      t.string "kind", null: false
      t.string "token_digest", null: false
      t.string "resource", null: false
      t.datetime "expires_at", null: false
      t.datetime "used_at"
      t.datetime "revoked_at"
      t.datetime "created_at", null: false
      t.index [ "token_digest" ], name: "index_nibble_oauth_tokens_on_token_digest", unique: true
      t.index [ "grant_id" ], name: "index_nibble_oauth_tokens_on_grant_id"
    end
  end
end
