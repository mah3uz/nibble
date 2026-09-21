class SiteController < ApplicationController
  allow_unauthenticated_access
  inertia_config(layout: "nibble")

  def show
    (match, queries) = Nibble::QueryCounter.count { Nibble::Routing.resolve(request.path) }
    return redirect_to(with_query(match.redirect), status: :moved_permanently) if match&.kind == :redirect
    return not_found(queries) unless match

    @nibble_locale = match.locale
    @nibble_integrations = Nibble::Integrations.settings if Nibble::Seo.indexable?
    declared = Nibble::PageProps.declared_params(match.template, request.query_parameters)
    key = Nibble::PageCache.key(request.host, request.path, declared.sort, request.headers["X-Inertia"].present?) if cacheable?
    return render_cached(key) if key && Nibble::PageCache.read(key)

    @nibble_view = match.template
    ((page, tags), more) = Nibble::QueryCounter.count { Nibble::Dependencies.track { build_props(match, declared) } }
    props = page.props
    @nibble_seo = page.seo
    count_queries(queries + more)
    render inertia: "theme/#{match.template}", props: props
    response.headers["Surrogate-Key"] = tags.sort.join(" ")
    Nibble::PageCache.write(key, tags, body: response.body, content_type: response.content_type) if key && response.status == 200
  rescue StandardError => error
    raise if response.committed?

    server_error(error)
  end

  private

  def render_cached(key)
    page = Nibble::PageCache.read(key)
    response.headers["Surrogate-Key"] = page.tags.join(" ")
    response.headers["X-Nibble-Cache"] = "hit"
    render body: page.body, content_type: page.content_type
  end

  def build_props(match, declared)
    Nibble::PageProps.new(match, params: declared, request_path: request.path, form_result: flash[:nibble_form]).build
  end

  def not_found(queries)
    Nibble::Records::NotFound.record(request.path, referrer: request.referer)
    locale = Nibble::Routing.locale_for(request.path)
    @nibble_integrations = Nibble::Integrations.settings if Nibble::Seo.indexable?
    error_match = Nibble::Routing::Match.new(kind: :error, record: nil, taxonomy: nil, collection: nil, locale:, template: "errors/404", redirect: nil)
    (page, more) = Nibble::QueryCounter.count { Nibble::PageProps.new(error_match, request_path: request.path).build }
    @nibble_seo = page.seo
    props = { "site" => page.props["site"], "seo" => @nibble_seo }
    count_queries(queries + more)
    render inertia: "theme/errors/404", props: props, status: :not_found
  end

  def server_error(error)
    Rails.logger.error("[nibble] rendering #{@nibble_view || request.path} failed: #{error.class}: #{error.message}")
    Rails.error.report(error, handled: true, context: { view: @nibble_view, path: request.path })
    render inertia: "theme/errors/500", props: {}, status: :internal_server_error
  end

  def cacheable?
    (request.get? || request.head?) && cookies[:session_id].blank? && flash.empty?
  end

  def count_queries(count)
    response.headers["X-Nibble-Queries"] = count.to_s unless Rails.env.production?
    Rails.logger.debug { "[nibble] #{request.path}: #{count} queries" }
  end

  def with_query(path) = request.query_string.empty? ? path : "#{path}?#{request.query_string}"
end
