module Nibble
  module Dev
    module Pages
      HTML_EXCERPT = 3_000

      module_function

      def tools
        [
          Tool.new(name: "schema_show", title: "Show the schema", read_only: true, handler: method(:schema_show),
            description: "The effective schema. With no key, every item and the layer it came from (core, theme or site); " \
                         "with a key like collections/posts, that item's definition and the file that defines it.",
            input: Dev.schema({ "key" => { "type" => "string" } })),
          Tool.new(name: "render", title: "Render a page", read_only: true, handler: method(:render),
            description: "Everything one request to a path produces, without a browser: what it resolved to, the view and " \
                         "layout files that answer it and whose they are, the view's queries, its props, cache tags, query " \
                         "count, time, the HTTP status, and any error with where it happened. Call it after changing a view.",
            input: Dev.schema({ "path" => { "type" => "string", "description" => "Like /blog/hello-world, with ?query if the view reads params" } }, %w[path])),
          Tool.new(name: "run_query_sidecar", title: "Run a view's queries", read_only: true, handler: method(:run_sidecar),
            description: "Run the queries in a theme view's .yml sidecar and return what each one gives the view.",
            input: Dev.schema({ "view" => { "type" => "string", "description" => "Like posts/index" },
                                "params" => { "type" => "object", "description" => "URL parameters the sidecar declares" } }, %w[view]))
        ]
      end

      def schema_show(input)
        schema = Nibble.schema
        if (key = input["key"].presence)
          item = schema.items.find { |candidate| candidate.key == key } or return { "error" => "no schema item #{key}", "keys" => schema.items.map(&:key).sort.first(200) }

          return { "key" => item.key, "layer" => item.layer.to_s, "path" => Dev.relative(item.path), "definition" => item.data }
        end

        { "items" => schema.items.sort_by(&:key).map { |item| { "key" => item.key, "layer" => item.layer.to_s, "path" => Dev.relative(item.path) } } }
      end

      def render(input)
        path, query = input["path"].to_s.split("?", 2)
        path = Uris.normalize(path.presence || "/")
        params = Rack::Utils.parse_nested_query(query.to_s)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        match, queries = QueryCounter.count { Routing.resolve(path) }
        return http(input["path"]).merge("resolved" => nil, "hint" => "No entry, term or listing answers #{path}.") unless match
        return { "resolved" => { "kind" => "redirect", "to" => match.redirect } } if match.kind == :redirect

        declared = PageProps.declared_params(match.template, params)
        ((page, tags), more) = QueryCounter.count { Dependencies.track { PageProps.new(match, params: declared, request_path: path).build } }
        {
          "resolved" => { "kind" => match.kind.to_s, "template" => match.template, "locale" => match.locale,
                          "record" => match.record && { "type" => match.record.record_type, "id" => match.record.id, "title" => match.record.title } }.compact,
          "view" => view_file("views", match.template), "layout" => view_file("layouts", page.props["layout"]),
          "sidecar" => sidecar(match.template), "props" => Dev.compact(page.props), "cache_tags" => tags.sort,
          "queries" => queries + more, "props_ms" => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        }.merge(http(input["path"]))
      rescue StandardError => error
        { "error" => failure(error) }
      end

      def run_sidecar(input)
        view = input["view"].to_s
        sidecar = Views.sidecar(view)
        return { "error" => "#{view} has no query sidecar", "hint" => "Sidecars sit beside views as views/#{view}.yml" } unless sidecar.path

        match = Routing::Match.new(kind: :view, record: nil, taxonomy: nil, collection: nil, locale: Nibble.config.default_locale.code, template: view, redirect: nil)
        props = PageProps.new(match, params: input["params"].to_h).build.props
        { "sidecar" => sidecar(view), "results" => Dev.compact(props.slice(*sidecar.queries.keys)) }
      rescue StandardError => error
        { "error" => failure(error) }
      end

      def view_file(folder, name)
        return nil if name.blank?

        [ Nibble.config.theme_path, Nibble.core_root.join("themes", Nibble.config.theme.to_s) ].compact.uniq
          .map { |dir| dir.join(folder, "#{name}.vue") }.find(&:file?)
          &.then { |file| { "path" => Dev.relative(file), "owner" => Dev.owner(file) } }
      end

      def sidecar(view)
        sidecar = Views.sidecar(view)
        sidecar.path && { "path" => Dev.relative(sidecar.path), "params" => sidecar.params, "queries" => sidecar.queries }
      end

      def http(path)
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.host = URI.parse(Nibble.config.url.presence || "http://localhost").host
        session.get(path)
        body = session.response.body.to_s
        rendered = Nokogiri::HTML5(body).at_css("#app")&.inner_html.to_s.strip
        { "status" => session.response.status, "html_excerpt" => Dev.clip(rendered.presence || body, HTML_EXCERPT),
          "server_rendered" => rendered.present?, "error" => (Logs.last_error_since(started_at: 5.seconds.ago) if session.response.status >= 500) }.compact
      end

      def failure(error)
        frame = Rails.backtrace_cleaner.clean(error.backtrace.to_a).first || error.backtrace.to_a.first
        { "class" => error.class.name, "message" => Dev.clip(error.message, 2_000), "at" => frame,
          "owner" => frame && Dev.owner(frame.split(":").first) }
      end
    end
  end
end
