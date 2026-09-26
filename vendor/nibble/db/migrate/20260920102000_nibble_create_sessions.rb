class NibbleCreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_sessions" do |t|
      t.datetime "created_at", null: false
      t.datetime "elevated_at"
      t.string "ip_address"
      t.datetime "last_active_at"
      t.datetime "updated_at", null: false
      t.string "user_agent"
      t.integer "user_id", null: false
      t.index [ "user_id" ], name: "index_nibble_sessions_on_user_id"
    end
  end
end
