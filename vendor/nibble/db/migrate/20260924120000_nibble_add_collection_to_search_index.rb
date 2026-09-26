# FTS5 tables can't gain a column, so both are recreated; nibble:prepare refills an empty index.
class NibbleAddCollectionToSearchIndex < ActiveRecord::Migration[8.1]
  TABLES = { "search_index" => "porter unicode61 remove_diacritics 2", "search_index_trigram" => "trigram remove_diacritics 1" }.freeze
  COLUMNS = [ "title", "body", "record_type UNINDEXED", "record_id UNINDEXED", "index_handle UNINDEXED", "locale UNINDEXED" ].freeze

  def up
    TABLES.each do |table, tokenizer|
      drop_virtual_table table, "fts5", [ *COLUMNS, "tokenize = '#{tokenizer}'" ]
      create_virtual_table table, "fts5", [ *COLUMNS, "collection UNINDEXED", "tokenize = '#{tokenizer}'" ]
    end
  end

  def down
    TABLES.each do |table, tokenizer|
      drop_virtual_table table, "fts5", [ *COLUMNS, "collection UNINDEXED", "tokenize = '#{tokenizer}'" ]
      create_virtual_table table, "fts5", [ *COLUMNS, "tokenize = '#{tokenizer}'" ]
    end
  end
end
