class NibbleCreateAssetFolders < ActiveRecord::Migration[8.1]
  def change
    create_table "asset_folders" do |t|
      t.datetime "created_at", null: false
      t.integer "parent_id"
      t.string "path", null: false
      t.datetime "updated_at", null: false
      t.index [ "parent_id" ], name: "index_asset_folders_on_parent_id"
      t.index [ "path" ], name: "index_asset_folders_on_path", unique: true
    end
    add_foreign_key "asset_folders", "asset_folders", column: "parent_id"
  end
end
