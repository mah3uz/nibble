class NibbleAddLastActiveAtToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :nibble_sessions, :last_active_at, :datetime
  end
end
