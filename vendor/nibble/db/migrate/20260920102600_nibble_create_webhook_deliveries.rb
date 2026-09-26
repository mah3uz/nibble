class NibbleCreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table "webhook_deliveries" do |t|
      t.integer "attempts", default: 0, null: false
      t.datetime "created_at", null: false
      t.datetime "delivered_at"
      t.string "error"
      t.string "event", null: false
      t.integer "event_id"
      t.datetime "next_attempt_at"
      t.json "payload", default: {}, null: false
      t.integer "response_status"
      t.string "status", default: "pending", null: false
      t.datetime "updated_at", null: false
      t.integer "webhook_id", null: false
      t.index [ "created_at" ], name: "index_webhook_deliveries_on_created_at"
      t.index [ "webhook_id", "created_at" ], name: "index_webhook_deliveries_on_webhook_id_and_created_at"
      t.index [ "webhook_id" ], name: "index_webhook_deliveries_on_webhook_id"
    end
  end
end
