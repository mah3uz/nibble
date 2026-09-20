module Admin
  class TaxonomiesController < BaseController
    def show
      taxonomy = Nibble.schema.taxonomy(params[:handle]) or raise ActiveRecord::RecordNotFound
      authorize!("terms.#{taxonomy.handle}.view")

      listing = Nibble::Cp::Listing.new(taxonomy, user: Current.user, params:)
      render inertia: "admin/taxonomies/Index", props: {
        taxonomy: { handle: taxonomy.handle, title: taxonomy["title"] },
        listing: listing.props
      }
    end
  end
end
