class NibbleCreateApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_approvals" do |t|
      t.integer "grant_id", null: false
      t.string "public_id", null: false
      t.string "operation", null: false
      t.json "input", default: {}, null: false
      t.json "preview", default: {}, null: false
      t.string "digest", null: false
      t.string "status", default: "pending", null: false
      t.datetime "decided_at"
      t.datetime "expires_at", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "public_id" ], name: "index_nibble_approvals_on_public_id", unique: true
      t.index [ "grant_id", "status" ], name: "index_nibble_approvals_on_grant_id_and_status"
    end
  end
end
