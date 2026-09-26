class NibblePrefixIdentityTables < ActiveRecord::Migration[8.1]
  TABLES = %w[users roles user_roles sessions user_credentials api_tokens sign_in_attempts].freeze

  def change
    TABLES.each { |table| rename_table table, "nibble_#{table}" }
  end
end
