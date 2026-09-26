class NibbleCreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table "webhooks", force: :cascade do |t|
      t.json "collections", default: [], null: false
      t.integer "consecutive_failures", default: 0, null: false
      t.datetime "created_at", null: false
      t.datetime "disabled_at"
      t.string "disabled_reason"
      t.boolean "enabled", default: true, null: false
      t.json "events", default: [], null: false
      t.string "name", null: false
      t.text "secret_ciphertext", null: false
      t.datetime "updated_at", null: false
      t.string "url", null: false
    end
  end
end
