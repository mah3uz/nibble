class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table "notifications", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.json "data", default: {}, null: false
      t.string "kind", null: false
      t.datetime "read_at"
      t.integer "subject_id"
      t.string "subject_type"
      t.datetime "updated_at", null: false
      t.integer "user_id", null: false
      t.index [ "user_id", "read_at", "created_at" ], name: "index_notifications_on_user_and_state"
    end
  end
end
