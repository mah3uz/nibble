class NibbleCreateIdempotencyKeys < ActiveRecord::Migration[8.1]
  def change
    create_table "idempotency_keys" do |t|
      t.integer "grant_id", null: false
      t.string "key", null: false
      t.string "operation", null: false
      t.string "digest", null: false
      t.json "response", default: {}, null: false
      t.datetime "created_at", null: false
      t.index [ "grant_id", "key" ], name: "index_idempotency_keys_on_grant_id_and_key", unique: true
      t.index [ "created_at" ], name: "index_idempotency_keys_on_created_at"
    end
  end
end
