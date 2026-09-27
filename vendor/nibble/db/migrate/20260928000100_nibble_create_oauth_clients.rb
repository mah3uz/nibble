class NibbleCreateOauthClients < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_oauth_clients" do |t|
      t.string "client_id", null: false
      t.string "kind", null: false
      t.string "name", null: false
      t.string "client_uri"
      t.json "redirect_uris", default: [], null: false
      t.datetime "fetched_at"
      t.string "registered_ip"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "client_id" ], name: "index_nibble_oauth_clients_on_client_id", unique: true
    end
  end
end
