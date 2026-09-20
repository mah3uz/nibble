module Admin
  class GlobalsController < BaseController
    def index
      sets = Nibble.schema.globals.select { |item| Nibble::Access.can?(Current.user, "globals.#{item.handle}.edit") }
      raise NotAuthorized if sets.empty?

      render inertia: "admin/globals/Index", props: {
        sets: sets.map { |item| { handle: item.handle, title: item["title"], url: "/admin/globals/#{item.handle}/edit" } }
      }
    end

    def edit
      item = Nibble.schema.find(:globals, params[:handle]) or raise ActiveRecord::RecordNotFound
      authorize!("globals.#{item.handle}.edit")
      record = global_set(item)
      blueprint = record.blueprint_definition
      fields = blueprint.fields.add_values(record.values)

      render inertia: "admin/globals/Edit", props: {
        title: item["title"],
        breadcrumbs: [ { label: "Globals", url: admin_globals_path }, { label: item["title"] } ],
        resource_key: "global",
        blueprint: blueprint.to_publish_h,
        values: fields.pre_process.values,
        field_meta: fields.meta,
        meta: { id: record.id, status: "published", live: true, lock_version: record.lock_version, permalink: nil,
                updated_at: record.updated_at&.utc&.iso8601, updated_by: nil, workflow: "simple", workflow_status: nil },
        draft: nil,
        can: { edit: true, publish: false, delete: false, review: false },
        urls: { update: edit_admin_global_path(item.handle).sub("/edit", ""), publish: nil, unpublish: nil, submit: nil,
                approve: nil, reject: nil, discard: nil, trash: nil, preview: nil, versions: nil,
                listing: admin_globals_path, create_another: nil }
      }
    end

    def update
      item = Nibble.schema.find(:globals, params[:handle]) or raise ActiveRecord::RecordNotFound
      authorize!("globals.#{item.handle}.edit")
      result = Nibble::Lifecycle.call(global_set(item), :save, attrs, actor: Current.user)
      return redirect_back_or_to(edit_admin_global_path(item.handle), inertia: { errors: result.errors.transform_values { |messages| Array(messages).first } }) unless result.ok?

      redirect_to edit_admin_global_path(item.handle), notice: "Saved."
    end

    private

    def global_set(item)
      locale = params[:locale].presence || Nibble.config.default_locale.code
      Nibble::Records::GlobalSet.find_or_initialize_by(handle: item.handle, locale:)
    end

    def attrs
      raw = params.fetch(:global, {})
      (raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw).to_h
    end
  end
end
