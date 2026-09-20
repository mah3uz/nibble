class CreateSearchIndex < ActiveRecord::Migration[8.1]
  def change
    create_virtual_table "search_index", "fts5", [ "title", "body", "record_type UNINDEXED", "record_id UNINDEXED", "index_handle UNINDEXED", "locale UNINDEXED", "tokenize = 'porter unicode61 remove_diacritics 2'" ]
  end
end
