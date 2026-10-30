module Nibble
  # A menu item that lists a collection's entries. It runs as a Query, so it reads published entries in the page's
  # locale and tags the page with the whole collection.
  class MenuQuery
    LIMIT = 50
    KEYS = %w[collection parent term sort limit].freeze

    def initialize(query, schema: Nibble.schema)
      @query = query.is_a?(Hash) ? query.deep_stringify_keys : {}
      @schema = schema
    end

    def collection = @query["collection"].to_s

    def problems(menu, locale)
      item = @schema.collection(collection)
      return [ "needs the collection it lists" ] if collection.empty?
      return [ "lists #{collection.humanize}, which this menu can't list" ] unless item && menu.queries.include?(collection)
      return [ "lists #{item['title'] || collection.humanize}, which is kept in the site's files, so a menu can't list it" ] if item["files"].present?

      unknown = @query.keys - KEYS
      [ ("has query settings it doesn't know: #{unknown.join(', ')}" if unknown.any?),
        parent_problem(item, locale), term_problem(item, locale), limit_problem, sort_problem ].compact
    end

    def records(context)
      query = Query.build(spec, context)
      Dependencies.add(query.spec.source.tag)
      scope = query.relation
      if (term = @query["term"])
        tagged = Records::Relation.where(source_type: "entry", field: term_fields, target_type: "term", target_id: term["id"])
        scope = scope.where(id: tagged.select(:source_id))
      end
      scope.limit(query.spec.limit).to_a
    end

    private

    def spec
      Query::Spec.parse({ "from" => "entries:#{collection}", "where" => ({ "parent_id" => @query["parent"] } if @query["parent"]),
                          "sort" => @query["sort"], "limit" => limit }.compact, schema: @schema)
    end

    def limit = @query["limit"].is_a?(Integer) && @query["limit"].between?(1, LIMIT) ? @query["limit"] : LIMIT

    def parent_problem(item, locale)
      return if @query["parent"].nil?

      parent = @query["parent"].is_a?(Integer) && Records::Entry.kept.find_by(id: @query["parent"], collection:, locale:)
      "lists the pages under a page that isn't in #{item['title'] || collection.humanize}, or has been deleted" unless parent
    end

    def term_problem(item, locale)
      term = @query["term"] or return
      return "needs the taxonomy and id of the term it lists by" unless term.is_a?(Hash) && term["taxonomy"].is_a?(String) && term["id"].is_a?(Integer)
      return "lists by #{term['taxonomy'].to_s.humanize}, which #{item['title'] || collection.humanize} isn't tagged with" if term_fields.empty?

      "lists by a term that's been deleted. Choose another" unless Records::Term.kept.exists?(id: term["id"], taxonomy: term["taxonomy"], locale:)
    end

    def limit_problem
      "can list from 1 to #{LIMIT} pages" unless @query["limit"].nil? || @query["limit"] == limit
    end

    def sort_problem
      spec
      nil
    rescue Query::Invalid => error
      "can't be sorted that way (#{error.message})"
    end

    # Only the collection's term fields that can hold the taxonomy count, so a page that merely links to the term isn't listed.
    def term_fields
      taxonomy = @query.dig("term", "taxonomy").to_s
      fields = Query::Source.new(kind: "entries", handle: collection).relation_fields(@schema).values
      fields.select { |field| field.fieldtype.is_a?(Fieldtypes::Terms) && Array(field.get("taxonomies")).then { |held| held.empty? || held.include?(taxonomy) } }
        .map(&:handle)
    end
  end
end
