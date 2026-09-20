class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table "comments", force: :cascade do |t|
      t.integer "author_id", null: false
      t.text "body", null: false
      t.datetime "created_at", null: false
      t.json "mentions", default: [], null: false
      t.integer "parent_id"
      t.datetime "resolved_at"
      t.integer "subject_id", null: false
      t.string "subject_type", null: false
      t.datetime "updated_at", null: false
      t.index [ "parent_id" ], name: "index_comments_on_parent_id"
      t.index [ "subject_type", "subject_id", "created_at" ], name: "index_comments_on_subject"
    end
  end
end
