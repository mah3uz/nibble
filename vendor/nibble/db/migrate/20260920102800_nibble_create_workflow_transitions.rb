class NibbleCreateWorkflowTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table "workflow_transitions", force: :cascade do |t|
      t.integer "actor_id"
      t.text "comment"
      t.datetime "created_at", null: false
      t.string "from", null: false
      t.integer "record_id", null: false
      t.string "record_type", null: false
      t.string "to", null: false
      t.index [ "actor_id" ], name: "index_workflow_transitions_on_actor_id"
      t.index [ "record_type", "record_id" ], name: "index_workflow_transitions_on_record"
    end
  end
end
