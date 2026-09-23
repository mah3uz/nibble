class InstallController < ActionController::API
  # The file the repository installs from, not a copy of it: the two would drift, and this one is run
  # unread by anyone who trusts the command on the home page.
  SCRIPT = Rails.root.join("install.sh")

  def show
    return head :not_found unless SCRIPT.file?

    response.headers["cache-control"] = "public, max-age=300"
    # Plain text so it can be read in a browser before it is run.
    render plain: SCRIPT.read, content_type: "text/plain"
  end
end
