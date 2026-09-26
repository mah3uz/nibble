class NibbleCreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_user_roles" do |t|
      t.datetime "created_at", null: false
      t.integer "role_id", null: false
      t.datetime "updated_at", null: false
      t.integer "user_id", null: false
      t.index [ "role_id" ], name: "index_nibble_user_roles_on_role_id"
      t.index [ "user_id", "role_id" ], name: "index_nibble_user_roles_on_user_id_and_role_id", unique: true
      t.index [ "user_id" ], name: "index_nibble_user_roles_on_user_id"
    end
    add_foreign_key "nibble_user_roles", "nibble_roles", column: "role_id", on_delete: :cascade
  end
end
