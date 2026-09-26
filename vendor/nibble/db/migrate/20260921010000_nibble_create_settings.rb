class NibbleCreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table "settings" do |t|
      t.datetime "created_at", null: false
      t.string "key", null: false
      t.datetime "updated_at", null: false
      t.json "value"
      t.index [ "key" ], name: "index_settings_on_key", unique: true
    end
  end
end
