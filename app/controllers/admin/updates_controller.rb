module Admin
  class UpdatesController < BaseController
    before_action { authorize!("utilities.view") }

    # Someone opening this page wants today's answer, not yesterday's, so it is read again here and re-cached.
    def show
      Nibble::Releases.refresh
      render inertia: "admin/Updates", props: {
        current: Nibble::VERSION,
        checking: Nibble::Releases.checking?,
        releases: Nibble::Releases.all.map(&:to_h)
      }
    end

    def update
      Nibble::Releases.checking = params[:checking].to_s == "true"
      Nibble::Releases.refresh if Nibble::Releases.checking?
      redirect_to admin_updates_path
    end
  end
end
