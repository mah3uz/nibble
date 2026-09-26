module Nibble
  module Cp
    module NibbleApi
      class RelationshipsController < BaseController
        MAX_RESULTS = 50

        # GET /cp/nibble/relationships/:type?q=&scope[collections][]=&limit=
        def index
          resolver = ::Nibble::Resolvers.find(params[:type])
          scope = params.fetch(:scope, {}).permit!.to_h.transform_values { |value| Array(value) }
          limit = params.fetch(:limit, 20).to_i.clamp(1, MAX_RESULTS)
          render json: { data: resolver.search(query: params[:q].to_s.strip, scope:, limit:) }
        rescue ::Nibble::Error
          head :not_found
        end
      end
    end
  end
end
