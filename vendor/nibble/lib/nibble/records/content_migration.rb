module Nibble
  module Records
    class ContentMigration < ::ApplicationRecord
      self.table_name = "content_migrations"
    end
  end
end
