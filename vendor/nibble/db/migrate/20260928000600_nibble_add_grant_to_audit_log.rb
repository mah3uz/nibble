class NibbleAddGrantToAuditLog < ActiveRecord::Migration[8.1]
  def change
    add_column "audit_log", "grant_id", :integer
  end
end
