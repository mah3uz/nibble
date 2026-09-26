class NibbleCreateGlobalSets < ActiveRecord::Migration[8.1]
  def change
    create_table "global_sets" do |t|
      t.datetime "created_at", null: false
      t.json "data", default: {}, null: false
      t.string "handle", null: false
      t.string "locale", null: false
      t.integer "lock_version", default: 0, null: false
      t.integer "origin_id"
      t.datetime "updated_at", null: false
      t.index [ "handle", "locale" ], name: "index_global_sets_on_handle_and_locale", unique: true
      t.index [ "origin_id" ], name: "index_global_sets_on_origin_id"
    end
    add_foreign_key "global_sets", "global_sets", column: "origin_id"
  end
end
