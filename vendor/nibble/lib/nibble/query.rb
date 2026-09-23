module Nibble
  class Query
    Result = Data.define(:records, :pagination, :spec, :snippets)

    PRESENTER_COLUMNS = %w[id uuid collection taxonomy blueprint locale title slug uri status published_at updated_at author_id].freeze

    def self.build(spec, context) = new(spec.is_a?(Spec) ? spec : Spec.parse(spec), context)

    attr_reader :spec, :context

    def initialize(spec, context)
      @spec = spec
      @context = context
    end

    def result
      Dependencies.add(spec.source.tag)
      return search_result if spec.source.search?
      return files_result if files_source?

      scope = relation
      pagination = nil
      if spec.paginate
        per_page = spec.paginate["per_page"]
        total = scope.count(:all)
        page = [ Integer(context.params[spec.paginate["param"]].to_s, exception: false) || 1, 1 ].max
        scope = scope.offset((page - 1) * per_page).limit(per_page)
        pagination = { "current_page" => page, "per_page" => per_page, "total" => total, "last_page" => [ (total / per_page.to_f).ceil, 1 ].max }
      else
        scope = scope.limit(spec.limit) if spec.limit
        scope = scope.offset(spec.offset) if spec.offset
      end
      Result.new(records: scope.to_a, pagination:, spec:, snippets: {})
    end

    def relation
      source = spec.source
      model = source.model
      scope = model.where(source.scope_column => source.handle, deleted_at: nil)
      scope = scope.where(status: "published") if source.entries? && context.public?
      scope = scope.where(locale: context.resolve(spec.locale || "$locale"))
      spec.conditions.each { |condition| scope = scope.where(node(model, condition)) }
      spec.exclusions.each { |condition| scope = scope.where(node(model, condition).not) }
      spec.sorts.each { |sort| scope = sort.field ? scope.order(field_order(model, sort)) : scope.order(sort.column => sort.direction) }
      scope = scope.order(:id)
      spec.column_fields_only? ? scope.select(*(PRESENTER_COLUMNS & model.column_names), *(spec.fields & model.column_names)) : scope
    end

    private

    # A folder is a different store, so a query over one filters the index instead of building a relation.
    def files_source? = spec.source.entries? && Files.collections.any? { |item| item.handle == spec.source.handle }

    def files_result
      pages = Files.index.of(spec.source.handle)
      spec.conditions.each { |condition| pages = pages.select { |page| matches?(page, condition) } }
      spec.exclusions.each { |condition| pages = pages.reject { |page| matches?(page, condition) } }
      spec.sorts.each do |sort|
        pages = pages.sort_by { |page| sort_key(value_for(page, sort.column)) }
        pages = pages.reverse if sort.direction.to_s == "desc"
      end
      total = pages.size
      pagination = nil
      if spec.paginate
        per_page = spec.paginate["per_page"]
        page = [ Integer(context.params[spec.paginate["param"]].to_s, exception: false) || 1, 1 ].max
        pages = pages[((page - 1) * per_page), per_page] || []
        pagination = { "current_page" => page, "per_page" => per_page, "total" => total, "last_page" => [ (total / per_page.to_f).ceil, 1 ].max }
      else
        pages = pages.drop(spec.offset.to_i)
        pages = pages.first(spec.limit) if spec.limit
      end
      Result.new(records: pages, pagination:, spec:, snippets: {})
    end

    # A page's own, already parsed; a frontmatter field of the same name would be the unparsed half of it.
    ATTRIBUTES = %w[id collection slug uri title blueprint locale template published_at position].freeze

    # A folder has no relations table, so a condition that reads one cannot be answered rather than ignored.
    def matches?(page, condition)
      raise Invalid.new("where", "cannot read relations on a collection kept as files") if condition.relation

      actual = value_for(page, condition.field)
      value = context.resolve(condition.value)
      case condition.operator
      when "eq" then actual == value
      when "ne" then actual != value
      when "in" then Array.wrap(value).include?(actual)
      when "lt" then sort_key(actual) < sort_key(value)
      when "lte" then sort_key(actual) <= sort_key(value)
      when "gt" then sort_key(actual) > sort_key(value)
      when "gte" then sort_key(actual) >= sort_key(value)
      when "null" then value ? actual.nil? : !actual.nil?
      when "prefix" then actual.to_s.downcase.start_with?(value.to_s.downcase)
      end
    end

    def value_for(page, column) = ATTRIBUTES.include?(column) ? page.public_send(column) : page.values[column]

    # As text "20" comes before "9" and one instant before another means nothing, so both compare as themselves.
    def sort_key(value)
      case value
      when Numeric then [ 0, value.to_f, "" ]
      when Time, Date then [ 0, value.to_time.to_f, "" ]
      else [ 1, 0.0, value.to_s ]
      end
    end

    # ->> is standard SQL/JSON, so this stays portable.
    def field_order(model, sort)
      path = Arel::Nodes::InfixOperation.new("->>", model.arel_table[:data], Arel::Nodes.build_quoted(sort.column))
      sort.direction == :desc ? path.desc : path.asc
    end

    def search_result
      per_page = spec.paginate&.dig("per_page") || spec.limit || 20
      page = spec.paginate ? [ Integer(context.params[spec.paginate["param"]].to_s, exception: false) || 1, 1 ].max : 1
      offset = spec.paginate ? (page - 1) * per_page : spec.offset.to_i
      locale = context.resolve(spec.locale || "$locale")
      found = Nibble::Search.search(spec.source.handle, context.resolve(spec.q), locale:, limit: per_page, offset:)
      loaded = found.hits.group_by(&:record_type).flat_map do |type, hits|
        next hits.filter_map { |hit| Files.index.find(hit.record_id) } if type == Files::Page::RECORD_TYPE

        scope = Records.model(type).where(id: hits.map(&:record_id), deleted_at: nil)
        scope = scope.where(status: "published") if type == "entry" && context.public?
        scope.to_a
      end.index_by { |record| [ record.record_type, record.id.to_s ] }
      hits = found.hits.select { |hit| loaded.key?([ hit.record_type, hit.record_id.to_s ]) }
      pagination = spec.paginate && { "current_page" => page, "per_page" => per_page, "total" => found.total, "last_page" => [ (found.total / per_page.to_f).ceil, 1 ].max }
      Result.new(records: hits.map { |hit| loaded[[ hit.record_type, hit.record_id.to_s ]] }, pagination:, spec:,
        snippets: hits.to_h { |hit| [ "#{hit.record_type}:#{hit.record_id}", hit.snippet ] })
    end

    def node(model, condition)
      table = model.arel_table
      value = context.resolve(condition.value)
      condition.relation ? relation_node(table, condition, value) : column_node(table[condition.field], condition.operator, value)
    end

    def column_node(column, operator, value)
      case operator
      when "eq" then value.nil? ? column.eq(nil) : column.eq(value)
      when "ne" then column.not_eq(value)
      when "in" then column.in(Array.wrap(value))
      when "lt" then column.lt(value)
      when "lte" then column.lteq(value)
      when "gt" then column.gt(value)
      when "gte" then column.gteq(value)
      when "null" then value ? column.eq(nil) : column.not_eq(nil)
      when "prefix" then column.matches("#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%", nil, true)
      end
    end

    def relation_node(table, condition, value)
      ids = Array.wrap(value).filter_map { |id| Integer(id.to_s, exception: false) }
      sources = ->(targets) { relations(condition.field).where(target_id: targets).select(:source_id).arel }
      case condition.operator
      when "in" then table[:id].in(sources.(ids))
      when "none" then table[:id].not_in(sources.(ids))
      when "all" then ids.empty? ? Arel::Nodes::True.new : ids.map { |id| table[:id].in(sources.([ id ])) }.reduce(:and)
      end
    end

    def relations(field) = Records::Relation.where(source_type: spec.source.record_type, field:)
  end
end
