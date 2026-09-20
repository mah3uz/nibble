module Admin
  class DashboardController < BaseController
    def show
      render inertia: "admin/Dashboard", props: {
        layout: Nibble::Cp::Widgets.layout(Current.user),
        available: Nibble::Cp::Widgets.available(Current.user),
        data: InertiaRails.defer { Nibble::Cp::Widgets.data(Current.user) }
      }
    end
  end
end
