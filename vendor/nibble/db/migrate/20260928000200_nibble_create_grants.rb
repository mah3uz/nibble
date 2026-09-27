class NibbleCreateGrants < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_grants" do |t|
      t.integer "user_id", null: false
      t.integer "oauth_client_id"
      t.string "kind", null: false
      t.string "name", null: false
      t.string "preset", null: false
      t.json "abilities", default: [], null: false
      t.string "via"
      t.datetime "last_used_at"
      t.string "last_used_ip"
      t.datetime "expires_at", null: false
      t.datetime "revoked_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "user_id" ], name: "index_nibble_grants_on_user_id"
      t.index [ "oauth_client_id" ], name: "index_nibble_grants_on_oauth_client_id"
    end
  end
end
