module Nibble
  class ApplicationController < ActionController::Base
    include Nibble::Authentication
    # No `allow_browser` restriction: the public site must serve every visitor.
  end
end
