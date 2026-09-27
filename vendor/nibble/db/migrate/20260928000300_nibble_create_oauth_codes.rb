class NibbleCreateOauthCodes < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_oauth_codes" do |t|
      t.integer "grant_id", null: false
      t.string "code_digest", null: false
      t.string "redirect_uri", null: false
      t.string "code_challenge", null: false
      t.string "resource", null: false
      t.datetime "expires_at", null: false
      t.datetime "used_at"
      t.datetime "created_at", null: false
      t.index [ "code_digest" ], name: "index_nibble_oauth_codes_on_code_digest", unique: true
      t.index [ "grant_id" ], name: "index_nibble_oauth_codes_on_grant_id"
    end
  end
end
