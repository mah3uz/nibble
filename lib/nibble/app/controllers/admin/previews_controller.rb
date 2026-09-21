module Admin
  class PreviewsController < BaseController
    inertia_config(layout: "nibble")

    def show
      collection = Nibble.schema.collection(params[:handle]) or raise ActiveRecord::RecordNotFound
      authorize!("entries.#{collection.handle}.view")
      entry = Nibble::Records::Entry.where(collection: collection.handle).find(params[:id])

      preview = preview_entry(entry)
      match = Nibble::Routing::Match.new(kind: :entry, record: preview, taxonomy: nil, collection: nil, locale: preview.locale,
        template: template_for(preview), redirect: nil)
      page = Nibble::PageProps.new(match, params: request.query_parameters, request_path: preview.uri || "/", preview: true).build

      response.headers["X-Robots-Tag"] = "noindex, nofollow"
      response.headers["Cache-Control"] = "no-store"
      render inertia: "theme/#{match.template}", props: page.props
    end

    private

    def preview_entry(entry)
      snapshot = entry.snapshot.merge(entry.draft&.data || {}).merge(posted_values)
      entry.dup.tap do |copy|
        copy.id = entry.id
        copy.assign_snapshot(entry.blueprint_definition.fields.add_values(snapshot).process.values.merge(snapshot.slice(*Nibble::Records::Entry::COLUMNS)))
        copy.uri = entry.uri
      end
    end

    def posted_values
      return JSON.parse(params[:entry_json]).to_h if params[:entry_json].present?

      raw = params.fetch(:entry, {})
      (raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw).to_h
    rescue JSON::ParserError
      {}
    end

    def template_for(entry)
      entry.template.presence || entry.blueprint_item["template"] || entry.collection_item["template"] || "default"
    end
  end
end
