module Nibble
  class PageProps
    Result = Data.define(:props, :seo, :view)

    # inertia-rails records where to append before it runs the prop that would say so, so the path is set when built.
    class ScrollingPage < InertiaRails::ScrollProp
      def initialize(...)
        super
        append("data")
      end
    end

    def initialize(match, params: {}, request_path: nil, preview: false, form_result: nil)
      @match = match
      @form_result = form_result
      @params = params
      @request_path = request_path || match.record&.uri || "/"
      @preview = preview
    end

    def build
      sidecar = Views.sidecar(@match.template)
      declared = @params.slice(*sidecar.params, *Views.set_params)
      context = Query::Context.public(locale: @match.locale, entry: (@match.record if @match.kind == :entry),
        term: (@match.record if @match.kind == :term), params: declared)
      presenter = Presenter.new(context:)

      page = present_page(presenter)
      run_set_sidecars(page, context, presenter)
      site = site_props(context, presenter, declared)
      seo = Seo.new(page:, site:, kind: @match.kind, url: site["url"]).to_h
      props = { "page" => page, "layout" => layout_for }
        .merge(run_queries(sidecar.queries, context, presenter))
        .merge("site" => site, "seo" => seo, "preview" => preview_prop)
      Result.new(props:, seo:, view: @match.template)
    end

    def self.declared_params(template, params) = params.slice(*Views.sidecar(template).params, *Views.set_params)

    private

    def present_page(presenter)
      return presenter.present([ @match.record ]).first if @match.record
      return { "collection" => @match.collection.handle, "title" => @match.collection["title"] } if @match.collection
      return { "title" => "Page not found" } unless @match.taxonomy

      { "taxonomy" => @match.taxonomy.handle, "title" => @match.taxonomy["title"] }
    end

    def preview_prop
      return nil unless @preview

      { "label" => "Unpublished changes", "edit_url" => nil }
    end

    def run_queries(queries, context, presenter)
      queries.to_h do |name, spec|
        spec = Query::Spec.parse(spec)
        next [ name, Forms::Definition.call(Forms.find(spec.source.handle), result: @form_result) ] if spec.source.form?

        result = Query.build(spec, context).result
        data = presenter.present(result.records, fields: result.spec.fields, include: result.spec.include)
        data.each { |item| item["search_snippet"] = result.snippets["#{item['type']}:#{item['id']}"] } if result.snippets.any?
        [ name, result.pagination ? paginated(result, data) : data ]
      end
    end

    # A scrolling query is one Inertia appends to, so a theme's InfiniteScroll adds each page's data to the last.
    def paginated(result, data)
      value = { "data" => data, "meta" => result.pagination }
      return value unless result.spec.paginate["scroll"]

      current, last = result.pagination.values_at("current_page", "last_page")
      metadata = { page_name: result.spec.paginate["param"], current_page: current,
                   previous_page: (current - 1 if current > 1), next_page: (current + 1 if current < last) }
      ScrollingPage.new(metadata:) { value }
    end

    def run_set_sidecars(value, context, presenter)
      case value
      when Array then value.each { |item| run_set_sidecars(item, context, presenter) }
      when Hash
        if value["id"].is_a?(String) && value["type"].is_a?(String) && (queries = Views.sidecar("sets/#{value['type']}").queries).any?
          value["queries"] = run_queries(queries, context.with(set: value), presenter)
        end
        value.each_value { |item| run_set_sidecars(item, context, presenter) }
      end
    end

    def site_props(context, presenter, declared)
      schema = Nibble.schema
      globals = Records::GlobalSet.where(locale: context.locale).index_by(&:handle)
      menus = Records::NavigationTree.where(locale: context.locale).index_by(&:handle)
      presenter.preload(globals.values + menus.values)
      Dependencies.add("global:#{Integrations::HANDLE}")
      {
        "locale" => context.locale, "url" => Presenter.url(@request_path), "params" => declared,
        "globals" => schema.globals.reject { |item| item.handle == Integrations::HANDLE }
          .to_h { |item| [ item.handle, present_global(presenter, globals[item.handle], item.handle) ] },
        "navigation" => schema.navigations.to_h { |item| [ item.handle, present_navigation(presenter, menus[item.handle], item.handle) ] }
      }
    end

    def present_global(presenter, record, handle)
      return presenter.present_global(record) if record

      Dependencies.add("global:#{handle}")
      {}
    end

    def present_navigation(presenter, record, handle)
      # A folder is its own tree, so a navigation named after one is read from the files rather than a record.
      return Files.index.tree(handle) if Files.collections.any? { |item| item.handle == handle }
      return presenter.present_navigation(record) if record

      Dependencies.add("navigation:#{handle}")
      []
    end

    def layout_for
      @match.item&.[]("layout") || "default"
    end
  end
end
