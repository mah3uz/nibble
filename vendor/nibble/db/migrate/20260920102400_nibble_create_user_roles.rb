class NibbleCreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table "user_roles", force: :cascade do |t|
      t.datetime "created_at", null: false
      t.integer "role_id", null: false
      t.datetime "updated_at", null: false
      t.integer "user_id", null: false
      t.index [ "role_id" ], name: "index_user_roles_on_role_id"
      t.index [ "user_id", "role_id" ], name: "index_user_roles_on_user_id_and_role_id", unique: true
      t.index [ "user_id" ], name: "index_user_roles_on_user_id"
    end
  end
end
