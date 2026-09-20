module Api
  module V1
    class RoutesController < BaseController
      before_action :readable!

      def show
        path = Nibble::Uris.normalize(params.require(:path))
        match = Nibble::Routing.resolve(path) or raise ActiveRecord::RecordNotFound

        respond({ "data" => route(match) })
      end

      private

      def route(match)
        { "kind" => match.kind.to_s, "locale" => match.locale, "template" => match.template,
          "redirect" => match.redirect, "uuid" => match.record&.uuid, "uri" => match.record&.uri,
          "collection" => match.record.try(:collection), "taxonomy" => match.taxonomy&.handle }.compact
      end
    end
  end
end
