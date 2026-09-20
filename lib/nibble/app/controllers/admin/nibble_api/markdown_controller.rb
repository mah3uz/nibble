module Admin
  module NibbleApi
    class MarkdownController < BaseController
      # POST /admin/nibble/markdown/preview
      # The editor shows what a theme will receive, which means rendering it the way the field will.
      def preview
        render json: { html: ::Nibble::Markdown.render(params[:text].to_s, sanitize: params[:sanitize] == "true") }
      end
    end
  end
end
