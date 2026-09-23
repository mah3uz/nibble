class NibbleRedirectsMiddleware
  SKIPPED = %r{\A/(?:admin|api|rails|vite|vite-dev|vite-test|vite-ssr|up)(?:/|\z)}

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    return @app.call(env) unless (request.get? || request.head?) && !request.path_info.match?(SKIPPED)

    id, target, status = Nibble::Records::Redirect.lookup(request.path_info, Nibble::Uris.normalize(request.path_info))
    return @app.call(env) unless target

    Nibble::Records::Redirect.hit!(id)
    location = request.query_string.empty? ? target : "#{target}#{target.include?('?') ? '&' : '?'}#{request.query_string}"
    [ status, { "location" => location, "content-type" => "text/html", "cache-control" => "public, max-age=300" }, [] ]
  end
end
