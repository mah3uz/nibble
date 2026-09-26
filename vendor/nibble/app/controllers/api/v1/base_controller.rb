module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::Caching

      PER_PAGE = 25

      rescue_from Nibble::Query::Invalid, with: :invalid_query
      rescue_from ActiveRecord::RecordNotFound, with: :not_found

      before_action :authenticate_token
      rate_limit to: 300, within: 1.minute, by: -> { request.headers["Authorization"].to_s }, with: -> { too_many }

      private

      def authenticate_token
        @token = Nibble::ApiToken.authenticate(bearer)
        return error(:unauthorized, "A valid API token is required.") unless @token

        touch_token
      end

      def bearer = request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip

      def touch_token
        return if @token.last_used_at && @token.last_used_at > 1.minute.ago

        @token.update_column(:last_used_at, Time.current)
      end

      def preview? = params[:preview].present? && @token.allows?("preview")

      def context(params_for_query = {})
        Nibble::Query::Context.new(locale: locale, now: Time.current, entry: nil, term: nil, set: nil,
          params: params_for_query.stringify_keys, scope: preview? ? :preview : :public)
      end

      def locale
        code = params[:locale].presence || Nibble.config.default_locale.code
        Nibble.config.locale(code) or raise Nibble::Query::Invalid.new("locale", "isn't a locale of this site")
        code
      end

      def presenter(query_context = context) = Nibble::Presenter.new(context: query_context, api: true)

      def spec_for(source)
        {
          "from" => source, "locale" => locale,
          "where" => filters, "sort" => sorts, "include" => list(:include), "fields" => list(:fields),
          "paginate" => { "per_page" => per_page, "param" => "page[number]" }
        }.compact_blank
      end

      def filters
        raw = params[:filter]
        return nil if raw.blank?
        raise Nibble::Query::Invalid.new("filter", "must be a map of fields") unless raw.respond_to?(:to_unsafe_h)

        raw.to_unsafe_h.transform_values { |value| value.is_a?(Hash) ? value.transform_values { |item| split(item) } : split(value) }
      end

      def sorts
        return nil if params[:sort].blank?

        params[:sort].to_s.split(",").map do |entry|
          entry.start_with?("-") ? "#{entry.delete_prefix('-')}:desc" : "#{entry}:asc"
        end
      end

      def list(key) = params[key].present? ? params[key].to_s.split(",") : nil

      def split(value) = value.to_s.include?(",") ? value.to_s.split(",") : value

      def per_page
        requested = params.dig(:page, :size).to_i
        requested.positive? ? [ requested, Nibble::Query::Spec::MAX_PER_PAGE ].min : PER_PAGE
      end

      def query(source)
        query_context = context("page[number]" => params.dig(:page, :number))
        result = Nibble::Query.build(spec_for(source), query_context).result
        data = presenter(query_context).present(result.records, fields: result.spec.fields, include: result.spec.include)
        respond({ "data" => data, "meta" => { "page" => result.pagination } }.compact)
      end

      def respond(body)
        response.headers["Cache-Control"] = "private, max-age=0, must-revalidate"
        render json: body if stale?(etag: [ body, @token.id ], public: false)
      end

      def collection!(handle)
        item = Nibble.schema.collection(handle)
        raise ActiveRecord::RecordNotFound unless item && item["api"]

        item
      end

      def taxonomy!(handle)
        item = Nibble.schema.taxonomy(handle)
        raise ActiveRecord::RecordNotFound unless item && item["api"]

        item
      end

      def readable!
        error(:forbidden, "This token can't read content.") unless @token.allows?("read")
      end

      def error(status, message) = render(json: { "errors" => [ { "status" => Rack::Utils.status_code(status).to_s, "detail" => message } ] }, status:)

      def invalid_query(problem) = error(:bad_request, problem.message)

      def not_found = error(:not_found, "No such content.")

      def too_many = error(:too_many_requests, "Too many requests. Slow down.")
    end
  end
end
