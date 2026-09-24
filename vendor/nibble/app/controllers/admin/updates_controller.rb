module Admin
  class UpdatesController < BaseController
    before_action { authorize!("utilities.view") }

    # Someone opening this page wants today's answer, not yesterday's, so it is read again here and re-cached.
    def show
      Nibble::Releases.refresh unless request.inertia_partial?
      number = [ params[:page].to_i, 1 ].max
      releases = Nibble::Releases.page(number)
      waiting = Nibble::Releases.summary
      render inertia: "admin/Updates", props: {
        current: Nibble::VERSION,
        checking: Nibble::Releases.checking?,
        waiting: { count: waiting.count, security: waiting.security },
        releases: InertiaRails.merge { releases.map { |release| release.to_h.merge(body: Nibble::Markdown.render(release.body)) } },
        page: number,
        more: releases.size == Nibble::Releases::PER_PAGE && !Nibble::Releases.last_page?(number)
      }
    end

    def update
      Nibble::Releases.checking = params[:checking].to_s == "true"
      Nibble::Releases.refresh if Nibble::Releases.checking?
      redirect_to admin_updates_path
    end
  end
end
