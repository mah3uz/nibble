module Nibble
  class ApplicationController < ActionController::Base
    include Nibble::Authentication

    inertia_config(on_ssr_error: ->(error, page) { Nibble::Dev::Logs.ssr(error, page) })
    # No `allow_browser` restriction: the public site must serve every visitor.
  end
end
