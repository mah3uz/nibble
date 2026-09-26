class NibbleCreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table "entries", force: :cascade do |t|
      t.integer "author_id"
      t.string "blueprint", null: false
      t.string "collection", null: false
      t.datetime "created_at", null: false
      t.integer "created_by_id"
      t.json "data", default: {}, null: false
      t.datetime "deleted_at"
      t.string "locale", null: false
      t.integer "lock_version", default: 0, null: false
      t.integer "origin_id"
      t.integer "parent_id"
      t.integer "position"
      t.datetime "published_at"
      t.string "slug"
      t.string "status", default: "draft", null: false
      t.string "template"
      t.string "title"
      t.datetime "unpublish_at"
      t.datetime "updated_at", null: false
      t.integer "updated_by_id"
      t.string "uri"
      t.string "uuid", null: false
      t.index [ "author_id" ], name: "index_entries_on_author_id"
      t.index [ "collection", "locale", "parent_id", "slug" ], name: "index_entries_on_collection_and_locale_and_parent_id_and_slug", unique: true, where: "deleted_at IS NULL"
      t.index [ "collection", "locale", "status", "published_at" ], name: "idx_on_collection_locale_status_published_at_43657fb133"
      t.index [ "collection", "parent_id", "position" ], name: "index_entries_on_collection_and_parent_id_and_position"
      t.index [ "collection", "published_at" ], name: "index_entries_on_collection_and_published_at"
      t.index [ "created_by_id" ], name: "index_entries_on_created_by_id"
      t.index [ "deleted_at" ], name: "index_entries_on_deleted_at"
      t.index [ "origin_id" ], name: "index_entries_on_origin_id"
      t.index [ "parent_id" ], name: "index_entries_on_parent_id"
      t.index [ "updated_by_id" ], name: "index_entries_on_updated_by_id"
      t.index [ "uri" ], name: "index_entries_on_uri", unique: true, where: "deleted_at IS NULL"
      t.index [ "uuid" ], name: "index_entries_on_uuid", unique: true
    end
  end
end
