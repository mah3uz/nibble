class NibbleCreateFormSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table "form_submissions", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.json "data", default: {}, null: false
      t.json "deliveries", default: [], null: false
      t.string "form", null: false
      t.string "ip_hash"
      t.string "locale"
      t.datetime "read_at"
      t.string "status", default: "received", null: false
      t.datetime "updated_at", null: false
      t.string "user_agent"
      t.index [ "form", "created_at" ], name: "index_form_submissions_on_form_and_created_at"
      t.index [ "form", "status" ], name: "index_form_submissions_on_form_and_status"
    end
  end
end
