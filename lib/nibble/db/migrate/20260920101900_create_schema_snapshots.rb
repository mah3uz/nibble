class CreateSchemaSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table "schema_snapshots", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.string "digest", null: false
      t.json "types", default: {}, null: false
    end
  end
end
