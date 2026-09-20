class ApplicationController < ActionController::Base
  include Authentication
  # No `allow_browser` restriction: the public site must serve every visitor.
end
