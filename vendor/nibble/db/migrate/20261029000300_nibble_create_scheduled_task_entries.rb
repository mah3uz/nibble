class NibbleCreateScheduledTaskEntries < ActiveRecord::Migration[8.1]
  def change
    create_table "scheduled_task_entries" do |t|
      t.string "handle", null: false
      t.string "collection", null: false
      t.string "key", null: false
      t.integer "entry_id", null: false
      t.datetime "missing_since"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "handle", "collection", "key" ], name: "index_scheduled_task_entries_on_handle_and_collection_and_key", unique: true
      t.index [ "entry_id" ], name: "index_scheduled_task_entries_on_entry_id"
    end
  end
end
