class CreateAuditLog < ActiveRecord::Migration[8.1]
  def change
    create_table "audit_log", force: :cascade do |t|
      t.string "action", null: false
      t.integer "actor_id"
      t.string "actor_type"
      t.json "changeset", default: {}, null: false
      t.datetime "created_at", null: false
      t.string "ip"
      t.integer "subject_id"
      t.string "subject_type"
      t.index [ "actor_type", "actor_id" ], name: "index_audit_log_on_actor"
      t.index [ "created_at" ], name: "index_audit_log_on_created_at"
      t.index [ "subject_type", "subject_id" ], name: "index_audit_log_on_subject"
    end
  end
end
