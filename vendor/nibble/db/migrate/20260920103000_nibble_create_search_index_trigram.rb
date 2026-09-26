class NibbleCreateSearchIndexTrigram < ActiveRecord::Migration[8.1]
  def change
    create_virtual_table "search_index_trigram", "fts5", [ "title", "body", "record_type UNINDEXED", "record_id UNINDEXED", "index_handle UNINDEXED", "locale UNINDEXED", "tokenize = 'trigram remove_diacritics 1'" ]
  end
end
