class FormRequestLimitMiddleware
  PATH = %r{\A/forms/([a-z0-9_-]+)\z}

  def initialize(app)
    @app = app
  end

  # Runs before Rack::MethodOverride, which would otherwise read the whole body to look for `_method`.
  def call(env)
    handle = env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"][PATH, 1]
    form = handle && Nibble::Forms.find(handle)
    return @app.call(env) unless form

    length = env["CONTENT_LENGTH"]
    return [ 411, { "content-type" => "text/plain" }, [ "Length Required" ] ] if length.blank?
    return [ 413, { "content-type" => "text/plain" }, [ "Content Too Large" ] ] if length.to_i > Nibble::Forms::Uploads.request_limit(form)

    @app.call(env)
  end
end
