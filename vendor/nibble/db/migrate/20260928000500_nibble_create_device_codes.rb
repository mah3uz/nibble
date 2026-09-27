class NibbleCreateDeviceCodes < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_device_codes" do |t|
      t.integer "oauth_client_id", null: false
      t.integer "grant_id"
      t.string "device_code_digest", null: false
      t.string "user_code", null: false
      t.string "resource", null: false
      t.string "requested_ip"
      t.string "status", default: "pending", null: false
      t.datetime "last_polled_at"
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.index [ "device_code_digest" ], name: "index_nibble_device_codes_on_device_code_digest", unique: true
      t.index [ "user_code" ], name: "index_nibble_device_codes_on_user_code", unique: true
    end
  end
end
