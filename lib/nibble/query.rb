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
        scope = Records.model(type).where(id: hits.map(&:record_id), deleted_at: nil)
        scope = scope.where(status: "published") if type == "entry" && context.public?
        scope.to_a
      end.index_by { |record| [ record.record_type, record.id ] }
      hits = found.hits.select { |hit| loaded.key?([ hit.record_type, hit.record_id ]) }
      pagination = spec.paginate && { "current_page" => page, "per_page" => per_page, "total" => found.total, "last_page" => [ (found.total / per_page.to_f).ceil, 1 ].max }
      Result.new(records: hits.map { |hit| loaded[[ hit.record_type, hit.record_id ]] }, pagination:, spec:,
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
