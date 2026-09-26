class NibbleCreateOutboundRequests < ActiveRecord::Migration[8.1]
  def change
    create_table "outbound_requests", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.integer "duration_ms"
      t.string "error"
      t.string "method", null: false
      t.integer "owner_id"
      t.string "owner_type"
      t.string "purpose", null: false
      t.text "request_body"
      t.json "request_headers", default: {}, null: false
      t.text "response_body"
      t.integer "status"
      t.string "url", null: false
      t.index [ "created_at" ], name: "index_outbound_requests_on_created_at"
      t.index [ "owner_type", "owner_id", "created_at" ], name: "idx_on_owner_type_owner_id_created_at_9cf9274ad2"
    end
  end
end
