class NibbleCarryOutApprovals < ActiveRecord::Migration[8.1]
  def up
    add_column :nibble_grants, :approval_mode, :string, default: "ask", null: false
    add_column :nibble_approvals, :result, :json
    add_column :nibble_approvals, :error, :json
    add_column :nibble_approvals, :idempotency_key, :string
    execute "UPDATE nibble_approvals SET status = 'done' WHERE status = 'used'"
  end

  def down
    execute "UPDATE nibble_approvals SET status = 'used' WHERE status IN ('done', 'failed')"
    remove_column :nibble_approvals, :idempotency_key
    remove_column :nibble_approvals, :error
    remove_column :nibble_approvals, :result
    remove_column :nibble_grants, :approval_mode
  end
end
