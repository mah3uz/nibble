module Nibble
  # The only place with SQLite-specific SQL (FTS5): another database means reimplementing this module, nothing else.
  module Search
    TABLES = { "porter" => "search_index", "trigram" => "search_index_trigram" }.freeze
    MARK_OPEN = "[[nibble-mark]]".freeze
    MARK_CLOSE = "[[/nibble-mark]]".freeze
    Hit = Data.define(:record_type, :record_id, :snippet)
    Page = Data.define(:hits, :total)

    class << self
      def indexes(schema: Nibble.schema) = schema.search&.data.to_h.fetch("indexes", {})

      def index_record(record)
        remove(record)
        return unless searchable?(record)

        memberships(record).each do |index|
          insert(table_for(record.locale), [ record.title.to_s, body(record, indexes[index]), record.record_type, record.id, index, record.locale ])
        end
      end

      def remove(record)
        TABLES.each_value do |table|
          run_sql("DELETE FROM #{table} WHERE record_type = ? AND record_id = ?", [ record.record_type, record.id ])
        end
      end

      def rebuild
        TABLES.each_value { |table| run_sql("DELETE FROM #{table}", []) }
        indexes.each_value do |definition|
          Array(definition["collections"]).each do |handle|
            Records::Entry.live.where(collection: handle).find_each { |entry| index_record(entry) }
            Files.index.of(handle).each { |page| index_record(page) }
          end
          Array(definition["taxonomies"]).each { |handle| Records::Term.kept.where(taxonomy: handle).find_each { |term| index_record(term) } }
        end
      end

      def search(index, query, locale:, limit: 20, offset: 0)
        tokenizer = Nibble.config.locale(locale)&.search_tokenizer || "porter"
        match = match_expression(query, tokenizer) or return Page.new(hits: [], total: 0)
        table = TABLES.fetch(tokenizer)
        where = "#{table} MATCH ? AND index_handle = ? AND locale = ?"
        binds = [ match, index.to_s, locale.to_s ]
        connection.uncached do
          total = connection.select_value("SELECT COUNT(*) FROM #{table} WHERE #{where}", "Nibble search count", binds).to_i
          rows = connection.select_rows(
            "SELECT record_type, record_id, snippet(#{table}, 1, ?, ?, '…', 16) FROM #{table} WHERE #{where} ORDER BY rank LIMIT ? OFFSET ?",
            "Nibble search", [ MARK_OPEN, MARK_CLOSE, *binds, limit, offset ]
          )
          Page.new(hits: rows.map { |type, id, snippet| Hit.new(record_type: type, record_id: id, snippet: highlight(snippet)) }, total:)
        end
      end

      private

      def connection = Records::Entry.connection
      def run_sql(sql, binds) = connection.exec_query(sql, "Nibble search index", binds)
      def table_for(locale) = TABLES.fetch(Nibble.config.locale(locale)&.search_tokenizer || "porter")

      def insert(table, values)
        run_sql("INSERT INTO #{table} (title, body, record_type, record_id, index_handle, locale) VALUES (?, ?, ?, ?, ?, ?)", values)
      end

      def searchable?(record) = record.is_a?(Records::Term) ? !record.trashed? : record.live?


      def memberships(record)
        key = record.is_a?(Records::Term) ? "taxonomies" : "collections"
        scope = record.is_a?(Records::Term) ? record.taxonomy : record.collection
        indexes.select { |_, definition| Array(definition[key]).include?(scope) }.keys
      end

      def body(record, definition)
        fields = record.blueprint_fields
        handles = Array(definition["fields"]) - [ "title" ]
        handles = fields.handles - [ "title" ] if handles.empty?
        text = handles.filter_map do |handle|
          field = fields.get(handle) or next
          field.fieldtype.search_text(record.values[handle])
        end
        # A file's words are in the file, not in a field, so they are read rather than looked up.
        text << record.body if record.is_a?(Files::Page)
        text.join("\n")
      end

      def match_expression(query, tokenizer)
        if tokenizer == "trigram"
          text = query.to_s.strip.delete('"')
          text.length >= 3 ? %("#{text}") : nil
        else
          terms = query.to_s.scan(/[\p{L}\p{N}]+/).first(10)
          terms.empty? ? nil : terms.map { |term| %("#{term}"*) }.join(" ")
        end
      end

      def highlight(snippet) = ERB::Util.html_escape(snippet.to_s).gsub(MARK_OPEN, "<mark>").gsub(MARK_CLOSE, "</mark>")
    end
  end
end
