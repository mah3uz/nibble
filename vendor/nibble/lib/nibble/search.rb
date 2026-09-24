module Nibble
  # The only place with SQLite-specific SQL (FTS5): another database means reimplementing this module, nothing else.
  module Search
    COLLECTION_KEYS_SINCE = "0.15.0".freeze
    KEYS_ONLY_SINCE = "0.17.0".freeze
    TABLES = { "porter" => "search_index", "trigram" => "search_index_trigram" }.freeze
    MARK_OPEN = "[[nibble-mark]]".freeze
    MARK_CLOSE = "[[/nibble-mark]]".freeze
    Hit = Data.define(:record_type, :record_id, :snippet)
    Page = Data.define(:hits, :total)

    class << self
      # A collection or taxonomy joins an index with its own `search: <index>`, and `search: false` leaves every index.
      # search.yml names indexes and their settings; its own membership lists are read only on older defaults.
      def indexes(schema: Nibble.schema, config: Nibble.config)
        declared = schema.search&.data.to_h.fetch("indexes", {}).transform_values(&:to_h)
        return declared unless config.defaults_at_least?(COLLECTION_KEYS_SINCE)

        members = { "collections" => schema.collections }
        if config.defaults_at_least?(KEYS_ONLY_SINCE)
          declared.transform_values! { |definition| definition.except("collections", "taxonomies") }
          members["taxonomies"] = schema.taxonomies
        end
        members.each do |key, items|
          items.each do |item|
            case item["search"]
            when false
              declared.transform_values! { |definition| definition.merge(key => Array(definition[key]) - [ item.handle ]) }
            when String
              definition = declared[item["search"]].to_h
              declared[item["search"]] = definition.merge(key => Array(definition[key]) | [ item.handle ])
            end
          end
        end
        declared
      end

      def index_record(record)
        remove(record)
        insert_record(record) if searchable?(record)
      end

      # Pages written as files publish no events, so the folder is indexed as a whole whenever it is read.
      def sync_files
        connection.transaction do
          TABLES.each_value { |table| run_sql("DELETE FROM #{table} WHERE record_type = ?", [ Files::Page::RECORD_TYPE ]) }
          Files.index.pages.each { |page| insert_record(page) if searchable?(page) }
        end
      end

      def remove(record)
        TABLES.each_value do |table|
          run_sql("DELETE FROM #{table} WHERE record_type = ? AND record_id = ?", [ record.record_type, record.id ])
        end
      end

      def empty? = TABLES.values.none? { |table| run_sql("SELECT 1 FROM #{table} LIMIT 1", []).any? }

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

      def search(index, query, locale:, limit: 20, offset: 0, collections: nil)
        tokenizer = Nibble.config.locale(locale)&.search_tokenizer || "porter"
        match = match_expression(query, tokenizer) or return Page.new(hits: [], total: 0)
        table = TABLES.fetch(tokenizer)
        where = "#{table} MATCH ? AND index_handle = ? AND locale = ?"
        binds = [ match, index.to_s, locale.to_s ]
        if (collections = Array(collections).map(&:to_s).presence)
          where += " AND collection IN (#{collections.map { '?' }.join(', ')})"
          binds += collections
        end
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

      def insert_record(record)
        memberships(record).each do |index|
          insert(table_for(record.locale), [ record.title.to_s, body(record, indexes[index]), record.record_type, record.id, index, record.locale,
                                             record.respond_to?(:collection) ? record.collection : nil ])
        end
      end

      def insert(table, values)
        run_sql("INSERT INTO #{table} (title, body, record_type, record_id, index_handle, locale, collection) VALUES (?, ?, ?, ?, ?, ?, ?)", values)
      end

      def searchable?(record)
        return false if record.data.to_h["search"] == false

        record.is_a?(Records::Term) ? !record.trashed? : record.live?
      end


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
        text << Markdown.text(record.body) if record.is_a?(Files::Page) && !handles.include?(record.body_field)
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
