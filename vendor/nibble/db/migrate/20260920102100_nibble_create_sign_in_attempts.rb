class NibbleCreateSignInAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_sign_in_attempts" do |t|
      t.datetime "created_at", null: false
      t.string "email_digest", null: false
      t.string "ip"
      t.string "kind", default: "password", null: false
      t.index [ "email_digest", "created_at" ], name: "index_nibble_sign_in_attempts_on_email_digest_and_created_at"
    end
  end
end
