class CreateEventsOutbox < ActiveRecord::Migration[8.1]
  def change
    create_table "events_outbox", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.datetime "dispatched_at"
      t.string "name", null: false
      t.json "payload", default: {}, null: false
      t.index [ "dispatched_at" ], name: "index_events_outbox_on_dispatched_at"
    end
  end
end
