module Nibble
  module Records
    class ContentMigration < Nibble::ApplicationRecord
      self.table_name = "content_migrations"
    end
  end
end
