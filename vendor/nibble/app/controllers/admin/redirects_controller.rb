module Admin
  class RedirectsController < BaseController
    before_action { authorize!("redirects.manage") }

    def index
      render inertia: "admin/redirects/Index", props: {
        redirects: Nibble::Records::Redirect.order(:from).map { |redirect| props_for(redirect) },
        statuses: Nibble::Records::Redirect::STATUSES
      }
    end

    def create = save(Nibble::Records::Redirect.new(source: "manual"), "Redirect created.")
    def update = save(Nibble::Records::Redirect.find(params[:id]), "Redirect updated.")

    def destroy
      Nibble::Records::Redirect.find(params[:id]).destroy!
      redirect_to admin_redirects_path, notice: "Redirect deleted."
    end

    private

    def save(redirect, notice)
      redirect.assign_attributes(params.require(:redirect).permit(:from, :to, :status))
      return redirect_to(admin_redirects_path, inertia: { errors: redirect.errors.to_hash(true).transform_values(&:first) }) unless redirect.save

      redirect_to admin_redirects_path, notice:
    end

    def props_for(redirect)
      { id: redirect.id, from: redirect.from, to: redirect.to, status: redirect.status, source: redirect.source,
        hits: redirect.hits, last_hit_at: redirect.last_hit_at&.utc&.iso8601 }
    end
  end
end
