module Nibble
  module Cp
    class DashboardController < BaseController
      def show
        render inertia: "cp/Dashboard", props: {
          layout: Nibble::Cp::Widgets.layout(Nibble::Current.user),
          available: Nibble::Cp::Widgets.available(Nibble::Current.user),
          data: InertiaRails.defer { Nibble::Cp::Widgets.data(Nibble::Current.user) }
        }
      end
    end
  end
end
