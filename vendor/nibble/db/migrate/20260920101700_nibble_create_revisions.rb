class NibbleCreateRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table "revisions" do |t|
      t.integer "actor_id"
      t.datetime "created_at", null: false
      t.json "data", default: {}, null: false
      t.string "kind", null: false
      t.string "message"
      t.integer "number", null: false
      t.integer "record_id", null: false
      t.string "record_type", null: false
      t.index [ "actor_id" ], name: "index_revisions_on_actor_id"
      t.index [ "record_type", "record_id", "number" ], name: "index_revisions_on_record_type_and_record_id_and_number", unique: true
    end
  end
end
