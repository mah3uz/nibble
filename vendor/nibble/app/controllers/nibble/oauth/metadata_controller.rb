module Nibble
  module Oauth
    class MetadataController < EndpointController
      def authorization_server = render(json: Nibble::Oauth.server_metadata(request))

      def protected_resource
        resources = Nibble::Oauth.resources(request)
        resource = params[:resource].present? ? resources.values.find { |url| url.end_with?("/#{params[:resource]}") } : resources[:mcp]
        return head :not_found unless resource

        render json: Nibble::Oauth.resource_metadata(request, resource)
      end
    end
  end
end
