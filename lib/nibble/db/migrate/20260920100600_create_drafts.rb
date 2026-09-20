class CreateDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table "drafts", force: :cascade do |t|
      t.integer "author_id"
      t.datetime "created_at", null: false
      t.json "data", default: {}, null: false
      t.integer "record_id", null: false
      t.string "record_type", null: false
      t.datetime "updated_at", null: false
      t.string "workflow_status"
      t.index [ "author_id" ], name: "index_drafts_on_author_id"
      t.index [ "record_type", "record_id" ], name: "index_drafts_on_record", unique: true
    end
  end
end
