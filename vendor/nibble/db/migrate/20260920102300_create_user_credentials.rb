class CreateUserCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table "user_credentials", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.string "external_id", null: false
      t.datetime "last_used_at"
      t.string "name", null: false
      t.string "provider", default: "webauthn", null: false
      t.text "public_key", null: false
      t.integer "sign_count", default: 0, null: false
      t.datetime "updated_at", null: false
      t.integer "user_id", null: false
      t.index [ "external_id" ], name: "index_user_credentials_on_external_id", unique: true
      t.index [ "user_id" ], name: "index_user_credentials_on_user_id"
    end
  end
end
