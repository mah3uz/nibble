class NibbleCreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table "nibble_roles" do |t|
      t.json "abilities", default: [], null: false
      t.datetime "created_at", null: false
      t.string "handle", null: false
      t.boolean "require_2fa", default: false, null: false
      t.boolean "superuser", default: false, null: false
      t.string "title", null: false
      t.datetime "updated_at", null: false
      t.index [ "handle" ], name: "index_nibble_roles_on_handle", unique: true
    end
  end
end
