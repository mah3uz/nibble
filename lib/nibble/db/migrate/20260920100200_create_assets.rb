class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table "assets", force: :cascade do |t|
      t.string "alt"
      t.integer "blob_id", null: false
      t.text "caption"
      t.datetime "created_at", null: false
      t.string "credit"
      t.json "data", default: {}, null: false
      t.datetime "deleted_at"
      t.float "duration"
      t.json "edits", default: {}, null: false
      t.string "filename", null: false
      t.float "focal_x"
      t.float "focal_y"
      t.float "focal_zoom", default: 1.0, null: false
      t.string "folder", default: "", null: false
      t.integer "height"
      t.string "kind", default: "file", null: false
      t.integer "lock_version", default: 0, null: false
      t.string "mime", null: false
      t.bigint "size", null: false
      t.json "tags", default: [], null: false
      t.string "title"
      t.datetime "updated_at", null: false
      t.string "uuid", null: false
      t.integer "width"
      t.index [ "blob_id" ], name: "index_assets_on_blob_id"
      t.index [ "deleted_at" ], name: "index_assets_on_deleted_at"
      t.index [ "folder", "filename" ], name: "index_assets_on_folder_and_filename"
      t.index [ "kind", "deleted_at" ], name: "index_assets_on_kind_and_deleted_at"
      t.index [ "uuid" ], name: "index_assets_on_uuid", unique: true
    end
  end
end
