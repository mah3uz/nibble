class NibbleCreateRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table "redirects", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.string "from", null: false
      t.integer "hits", default: 0, null: false
      t.datetime "last_hit_at"
      t.string "source", default: "manual", null: false
      t.integer "status", default: 301, null: false
      t.string "to", null: false
      t.datetime "updated_at", null: false
      t.index [ "from" ], name: "index_redirects_on_from", unique: true
      t.index [ "to" ], name: "index_redirects_on_to"
    end
  end
end
