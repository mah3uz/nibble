module Nibble
  module Cp
    module NibbleApi
      class RelationshipsController < BaseController
        MAX_RESULTS = 50

        # GET /cp/nibble/relationships/:type?q=&scope[collections][]=&limit=&offset=
        def index
          resolver = ::Nibble::Resolvers.find(params[:type])
          scope = params.fetch(:scope, {}).permit!.to_h.transform_values { |value| Array(value) }
          limit = params.fetch(:limit, 20).to_i.clamp(1, MAX_RESULTS)
          offset = params[:offset].to_i
          paging = offset.positive? && pages?(resolver) ? { offset: } : {}
          render json: { data: resolver.search(query: params[:q].to_s.strip, scope:, limit:, **paging) }
        rescue ::Nibble::Error
          head :not_found
        end

        # POST /cp/nibble/relationships/:type  { target:, title:, values: {} }
        def create
          record, ability = new_record
          return head(:not_found) unless record

          authorize!(ability)
          return render json: { errors: { title: "Title can't be blank." } }, status: :unprocessable_entity if params[:title].to_s.strip.empty?

          fields = ::Nibble::Fieldtypes::Relationship.dialog_fields(record).pluck("handle")
          values = params.fetch(:values, {}).permit!.to_h.slice(*fields)
          result = ::Nibble::Lifecycle.call(record, :create, { "title" => params[:title].to_s.strip }.merge(values), actor: ::Nibble::Current.user)
          unless result.ok?
            return render json: { errors: result.errors.transform_values { |messages| Array(messages).first } }, status: :unprocessable_entity
          end

          render json: { data: ::Nibble::Resolvers.find(params[:type]).find([ result.record.id.to_s ]).first }, status: :created
        end

        private

        def pages?(resolver)
          resolver.method(:search).parameters.any? { |kind, name| kind == :keyrest || name == :offset }
        end

        def new_record
          case params[:type]
          when "entry"
            item = ::Nibble.schema.collection(params[:target].to_s)
            return if item.nil? || item["files"].present?

            [ ::Nibble::Records::Entry.new(collection: item.handle, blueprint: Array(item["blueprints"]).first), "entries.#{item.handle}.create" ]
          when "term"
            item = ::Nibble.schema.taxonomy(params[:target].to_s)
            return unless item

            [ ::Nibble::Records::Term.new(taxonomy: item.handle, blueprint: Array(item["blueprints"]).first), "terms.#{item.handle}.create" ]
          end
        end
      end
    end
  end
end
