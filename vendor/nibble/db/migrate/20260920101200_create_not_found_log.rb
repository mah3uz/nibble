class CreateNotFoundLog < ActiveRecord::Migration[8.1]
  def change
    create_table "not_found_log", force: :cascade do |t|
      t.datetime "first_seen_at", null: false
      t.integer "hits", default: 0, null: false
      t.datetime "last_seen_at", null: false
      t.string "path", null: false
      t.string "referrer"
      t.index [ "hits" ], name: "index_not_found_log_on_hits"
      t.index [ "path" ], name: "index_not_found_log_on_path", unique: true
    end
  end
end
