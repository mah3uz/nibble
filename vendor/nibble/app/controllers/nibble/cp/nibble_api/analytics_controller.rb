module Nibble
  module Cp
    module NibbleApi
      class AnalyticsController < BaseController
        # POST /cp/nibble/analytics/preview
        # An analytics card shows the tags it will write, from the renderer that writes them.
        def preview
          authorize!("globals.#{::Nibble::Integrations::HANDLE}.edit")
          card = params.fetch(:card, {}).to_unsafe_h.to_h.stringify_keys
          fields = ::Nibble::Integrations.analytics_fields(card["type"])
          errors = fields ? ::Nibble::Validator.new(fields, skip_required: true).validate(card).errors : {}
          tags = ::Nibble::Analytics.render([ card.except("enabled") ]).tags
          render json: { tags:, errors: errors.transform_values(&:first) }
        end
      end
    end
  end
end
