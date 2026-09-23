class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table "sessions", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.datetime "elevated_at"
      t.string "ip_address"
      t.datetime "updated_at", null: false
      t.string "user_agent"
      t.integer "user_id", null: false
      t.index [ "user_id" ], name: "index_sessions_on_user_id"
    end
  end
end
