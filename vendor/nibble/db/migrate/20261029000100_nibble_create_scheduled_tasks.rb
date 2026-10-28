class NibbleCreateScheduledTasks < ActiveRecord::Migration[8.1]
  def change
    create_table "scheduled_tasks" do |t|
      t.string "handle", null: false
      t.boolean "paused", default: false, null: false
      t.datetime "active_since", null: false
      t.integer "current_run_id"
      t.datetime "claimed_at"
      t.datetime "failing_since"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "handle" ], name: "index_scheduled_tasks_on_handle", unique: true
    end
  end
end
