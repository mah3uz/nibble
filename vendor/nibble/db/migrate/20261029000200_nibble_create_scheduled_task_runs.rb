class NibbleCreateScheduledTaskRuns < ActiveRecord::Migration[8.1]
  def change
    create_table "scheduled_task_runs" do |t|
      t.string "handle", null: false
      t.datetime "scheduled_for", null: false
      t.boolean "manual", default: false, null: false
      t.string "status", default: "queued", null: false
      t.datetime "started_at"
      t.datetime "finished_at"
      t.string "message"
      t.json "details", default: {}, null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index [ "handle", "scheduled_for" ], name: "index_scheduled_task_runs_on_handle_and_scheduled_for", unique: true
      t.index [ "created_at" ], name: "index_scheduled_task_runs_on_created_at"
    end
  end
end
