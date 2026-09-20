class CreateContentMigrations < ActiveRecord::Migration[8.1]
  def change
    create_table "content_migrations", force: :cascade do |t|
      t.string "name", null: false
      t.datetime "ran_at", null: false
      t.json "results", default: [], null: false
      t.index [ "name" ], name: "index_content_migrations_on_name", unique: true
    end
  end
end
