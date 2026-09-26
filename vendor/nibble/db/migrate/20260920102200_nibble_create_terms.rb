class NibbleCreateTerms < ActiveRecord::Migration[8.1]
  def change
    create_table "terms" do |t|
      t.string "blueprint", null: false
      t.datetime "created_at", null: false
      t.json "data", default: {}, null: false
      t.datetime "deleted_at"
      t.string "locale", null: false
      t.integer "lock_version", default: 0, null: false
      t.integer "origin_id"
      t.string "slug", null: false
      t.string "taxonomy", null: false
      t.string "title"
      t.datetime "updated_at", null: false
      t.string "uri"
      t.string "uuid", null: false
      t.index [ "deleted_at" ], name: "index_terms_on_deleted_at"
      t.index [ "origin_id" ], name: "index_terms_on_origin_id"
      t.index [ "taxonomy", "locale", "slug" ], name: "index_terms_on_taxonomy_and_locale_and_slug", unique: true, where: "deleted_at IS NULL"
      t.index [ "uri" ], name: "index_terms_on_uri"
      t.index [ "uuid" ], name: "index_terms_on_uuid", unique: true
    end
    add_foreign_key "terms", "terms", column: "origin_id"
  end
end
