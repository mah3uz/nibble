class NibbleCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table "users", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.string "email_address", null: false
      t.datetime "last_login_at"
      t.string "name", null: false
      t.string "password_digest", null: false
      t.json "preferences", default: {}, null: false
      t.json "recovery_codes", default: [], null: false
      t.datetime "totp_confirmed_at"
      t.datetime "totp_last_used_at"
      t.text "totp_secret_ciphertext"
      t.datetime "updated_at", null: false
      t.index [ "email_address" ], name: "index_users_on_email_address", unique: true
    end
  end
end
