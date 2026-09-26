class NibbleCreateRelations < ActiveRecord::Migration[8.1]
  def change
    create_table "relations", force: :cascade do |t|
      t.string "field", null: false
      t.string "locale", null: false
      t.integer "position", default: 0, null: false
      t.integer "source_id", null: false
      t.string "source_type", null: false
      t.integer "target_id", null: false
      t.string "target_type", null: false
      t.index [ "source_type", "source_id" ], name: "index_relations_on_source"
      t.index [ "target_type", "target_id" ], name: "index_relations_on_target"
    end
  end
end
