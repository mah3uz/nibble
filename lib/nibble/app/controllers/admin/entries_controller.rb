module Admin
  class EntriesController < BaseController
    before_action :load_collection
    before_action :load_entry, except: %i[new create reorder]

    def new
      authorize!(ability("create"))
      entry = Nibble::Records::Entry.new(collection: @collection.handle, blueprint: blueprint_handle, locale: locale)
      entry.published_at = starting_at if params[:date].present?
      render inertia: "admin/entries/Edit", props: editor_props(entry)
    end

    def create
      authorize!(ability("create"))
      entry = Nibble::Records::Entry.new(collection: @collection.handle, blueprint: blueprint_handle, locale: locale)
      result = Nibble::Lifecycle.call(entry, :create, attrs, actor: Current.user)
      return render_errors(entry, result) unless result.ok?

      redirect_to edit_admin_collection_entry_path(@collection.handle, result.record), notice: "#{@collection['title'].singularize} created."
    end

    def edit
      authorize!(ability("view"))
      render inertia: "admin/entries/Edit", props: editor_props(@entry)
    end

    def update = run(:save, "Saved.")
    def publish = run(:publish, "Published.", permission: "publish")
    def unpublish = run(:unpublish, "Unpublished.", permission: "publish")
    def submit = run(:submit, "Sent for review.")
    def approve = run(:approve, "Approved.", permission: "publish")
    def reject = run(:reject, "Sent back for changes.", permission: "publish")
    def revert = run(:revert, "Revision restored.")
    def discard_draft = run(:discard_draft, "Draft discarded.")

    def trash
      authorize!(ability("delete"), @entry)
      result = Nibble::Lifecycle.call(@entry, :trash, attrs, actor: Current.user)
      if result.needs_confirmation?
        return render json: { referrers: referrers(result) }, status: :conflict
      end
      return render_errors(@entry, result) unless result.ok?

      redirect_to admin_collection_root_path(@collection.handle), notice: "Moved to the trash."
    end

    def reorder
      authorize!(ability("edit"))
      Array(params[:order]).each_with_index do |row, position|
        entry = Nibble::Records::Entry.kept.find_by(id: row[:id], collection: @collection.handle) or next
        Nibble::Lifecycle.call(entry, :move, { "parent_id" => row[:parent_id].presence, "position" => position }, actor: Current.user)
      end
      redirect_back_or_to admin_collection_root_path(@collection.handle), notice: "Order saved."
    end

    private

    def starting_at
      parsed = Time.zone.parse(params[:date].to_s)
      return if parsed.nil?

      params[:date].to_s.include?("T") ? parsed : parsed.change(hour: 9)
    end

    def run(action, notice, permission: "edit")
      authorize!(ability(permission), @entry)
      result = Nibble::Lifecycle.call(@entry, action, attrs, actor: Current.user)
      return render_conflict(result) if result.conflict?
      return render_errors(@entry, result) unless result.ok?

      redirect_to edit_admin_collection_entry_path(@collection.handle, @entry), notice:
    end

    def render_errors(entry, result)
      redirect_back_or_to edit_path(entry), inertia: { errors: result.errors.transform_values { |messages| Array(messages).first } }
    end

    def render_conflict(result)
      redirect_back_or_to edit_path(@entry), inertia: { errors: { lock_version: result.errors["lock_version"].first } }
    end

    def edit_path(entry)
      entry.persisted? ? edit_admin_collection_entry_path(@collection.handle, entry) : new_admin_collection_entry_path(@collection.handle)
    end

    def referrers(result)
      result.referrers.map { |relation| { type: relation.source_type, title: relation.source.title, url: cp_url(relation.source) } }
    end

    def cp_url(record)
      record.is_a?(Nibble::Records::Entry) ? "/admin/collections/#{record.collection}/entries/#{record.id}" : "/admin/taxonomies/#{record.taxonomy}/terms/#{record.id}"
    end

    def load_collection
      @collection = Nibble.schema.collection(params[:handle]) or raise ActiveRecord::RecordNotFound
    end

    def load_entry
      @entry = Nibble::Records::Entry.where(collection: @collection.handle).find(params[:id])
    end

    def ability(action) = "entries.#{@collection.handle}.#{action}"
    def blueprint_handle = params[:blueprint].presence || Array(@collection["blueprints"]).first
    def locale = params[:locale].presence || Nibble.config.default_locale.code

    def attrs
      raw = params.fetch(:entry, {})
      raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
      raw = raw.to_h
      raw["parent_id"] = Array(raw.delete("parent")).compact_blank.first if raw.key?("parent")
      raw
    end

    def editor_props(entry)
      blueprint = entry.blueprint_definition
      source = entry.draft&.data || entry.snapshot
      fields = blueprint.fields.add_values(source)
      {
        title: entry.title.presence || (entry.persisted? ? "Untitled" : "New #{@collection['title'].to_s.singularize.downcase}"),
        breadcrumbs: [ { label: @collection["title"], url: admin_collection_root_path(@collection.handle) } ],
        resource_key: "entry",
        blueprint: with_sidebar(blueprint.to_publish_h, entry),
        values: fields.pre_process.values.merge(sidebar_values(entry)).merge("lock_version" => entry.lock_version),
        field_meta: fields.meta,
        meta: meta_props(entry),
        draft: draft_props(entry),
        can: {
          edit: Nibble::Access.can?(Current.user, ability("edit"), entry),
          publish: Nibble::Access.can?(Current.user, ability("publish"), entry),
          delete: Nibble::Access.can?(Current.user, ability("delete"), entry),
          review: Nibble::Access.can?(Current.user, "workflow.approve.#{@collection.handle}")
        },
        urls: urls(entry),
        parents: parent_options(entry)
      }
    end

    def sidebar_fields(entry)
      items = []
      if entry.collection_item["requires_slugs"] != false
        items << { "handle" => "slug", "field" => { "type" => "slug", "display" => "Slug", "from" => "title", "width" => 100 } }
      end
      if entry.dated?
        items << { "handle" => "published_at", "field" => { "type" => "date", "display" => "Publish date", "time_enabled" => true } }
      end
      if entry.expires?
        items << { "handle" => "unpublish_at", "field" => { "type" => "date", "display" => "Unpublish date", "time_enabled" => true } }
      end
      if entry.structured?
        items << { "handle" => "parent", "field" => { "type" => "entries", "display" => "Parent", "max_items" => 1,
                                                      "collections" => [ entry.collection ], "create" => false } }
      end
      items += taxonomy_items(entry)
      items << { "handle" => "template", "field" => { "type" => "select", "display" => "Template",
                                                      "options" => Nibble::Views.templates, "clearable" => true,
                                                      "instructions" => "Leave empty to use the collection's template." } }
      Nibble::Fields.new(items, schema: Nibble.schema, source: "entry sidebar")
    end

    def taxonomy_items(entry)
      handles = entry.blueprint_definition.fields.handles
      Array(entry.collection_item["taxonomies"]).filter_map do |handle|
        taxonomy = Nibble.schema.taxonomy(handle) or next
        next if handles.include?(handle)

        { "handle" => handle, "field" => { "type" => "terms", "taxonomies" => [ handle ], "display" => taxonomy["title"], "mode" => "select" } }
      end
    end

    def with_sidebar(publish_hash, entry)
      section = { "display" => nil, "instructions" => nil, "collapsible" => false, "collapsed" => false,
                  "fields" => sidebar_fields(entry).to_publish_a }
      tabs = publish_hash["tabs"]
      return publish_hash.merge("tabs" => tabs + [ { "handle" => "sidebar", "display" => "Details", "sections" => [ section ] } ]) if tabs.none? { |tab| tab["handle"] == "sidebar" }

      publish_hash.merge("tabs" => tabs.map do |tab|
        tab["handle"] == "sidebar" ? tab.merge("sections" => tab["sections"] + [ section ]) : tab
      end)
    end

    def sidebar_values(entry)
      values = entry.snapshot.slice(*Nibble::Records::Entry::COLUMNS).except("parent_id", "position", "author_id")
      values.merge("parent" => entry.parent_id ? [ entry.parent_id.to_s ] : [])
    end

    def meta_props(entry)
      {
        id: entry.id, status: entry.status, live: entry.live?, lock_version: entry.lock_version,
        permalink: entry.uri && "#{Nibble.config.url}#{entry.uri}",
        updated_at: entry.updated_at&.utc&.iso8601, updated_by: entry.updated_by_id && ::User.find_by(id: entry.updated_by_id)&.name,
        workflow: entry.persisted? ? entry.workflow : "simple",
        workflow_status: entry.draft&.workflow_status
      }
    end

    def draft_props(entry)
      draft = entry.draft or return nil

      { updated_at: draft.updated_at.utc.iso8601, user: draft.author&.name,
        stale: entry.updated_at > draft.updated_at }
    end

    def urls(entry)
      base = "/admin/collections/#{@collection.handle}/entries"
      return { update: base, publish: nil, unpublish: nil, submit: nil, approve: nil, reject: nil, discard: nil,
               trash: nil, preview: nil, versions: nil, comments: nil,
               listing: "/admin/collections/#{@collection.handle}", create_another: nil } unless entry.persisted?

      member = "#{base}/#{entry.id}"
      {
        update: member, publish: "#{member}/publish", unpublish: "#{member}/unpublish", submit: "#{member}/submit",
        approve: "#{member}/approve", reject: "#{member}/reject", discard: "#{member}/draft", trash: "#{member}/trash",
        preview: "#{member}/preview", versions: "#{member}/revisions", comments: "#{member}/comments",
        listing: "/admin/collections/#{@collection.handle}", create_another: "#{base}/new"
      }
    end

    def parent_options(entry)
      return [] unless @collection["structure"].is_a?(Hash)

      Nibble::Records::Entry.kept.where(collection: @collection.handle, locale: entry.locale).where.not(id: entry.id)
        .order(:uri).map { |option| { id: option.id, title: option.title, uri: option.uri } }
    end
  end
end
