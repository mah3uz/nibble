class NibbleCreateNavigationTrees < ActiveRecord::Migration[8.1]
  def change
    create_table "navigation_trees", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.string "handle", null: false
      t.string "locale", null: false
      t.integer "lock_version", default: 0, null: false
      t.json "tree", default: [], null: false
      t.datetime "updated_at", null: false
      t.index [ "handle", "locale" ], name: "index_navigation_trees_on_handle_and_locale", unique: true
    end
  end
end
