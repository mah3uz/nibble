module Nibble
  module Cp
    class TermsController < BaseController
      before_action :load_taxonomy
      before_action :load_term, only: %i[edit update trash]

      def new
        authorize!(ability("create"))
        render inertia: "cp/terms/Edit", props: editor_props(Nibble::Records::Term.new(taxonomy: @taxonomy.handle, blueprint: blueprint_handle, locale: locale))
      end

      def create
        authorize!(ability("create"))
        term = Nibble::Records::Term.new(taxonomy: @taxonomy.handle, blueprint: blueprint_handle, locale: locale)
        result = Nibble::Lifecycle.call(term, :create, attrs, actor: Nibble::Current.user)
        return redirect_back_or_to(new_cp_taxonomy_term_path(@taxonomy.handle), inertia: { errors: messages(result) }) unless result.ok?

        redirect_to edit_cp_taxonomy_term_path(@taxonomy.handle, result.record), notice: "Term created."
      end

      def edit
        authorize!(ability("view"))
        render inertia: "cp/terms/Edit", props: editor_props(@term)
      end

      def update
        authorize!(ability("edit"), @term)
        result = Nibble::Lifecycle.call(@term, :save, attrs, actor: Nibble::Current.user)
        return redirect_back_or_to(edit_path, inertia: { errors: messages(result) }) unless result.ok?

        redirect_to edit_path, notice: "Saved."
      end

      def trash
        authorize!(ability("delete"), @term)
        result = Nibble::Lifecycle.call(@term, :trash, attrs.merge("force" => true), actor: Nibble::Current.user)
        return redirect_back_or_to(edit_path, inertia: { errors: messages(result) }) unless result.ok?

        redirect_to cp_taxonomy_root_path(@taxonomy.handle), notice: "Moved to the trash."
      end

      private

      def load_taxonomy
        @taxonomy = Nibble.schema.taxonomy(params[:handle]) or raise ActiveRecord::RecordNotFound
      end

      def load_term
        @term = Nibble::Records::Term.where(taxonomy: @taxonomy.handle).find(params[:id])
      end

      def ability(action) = "terms.#{@taxonomy.handle}.#{action}"
      def blueprint_handle = params[:blueprint].presence || Array(@taxonomy["blueprints"]).first
      def locale = params[:locale].presence || Nibble.config.default_locale.code
      def edit_path = edit_cp_taxonomy_term_path(@taxonomy.handle, @term)
      def messages(result) = result.errors.transform_values { |messages| Array(messages).first }

      def attrs
        raw = params.fetch(:term, {})
        raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
        raw.to_h
      end

      def editor_props(term)
        blueprint = term.blueprint_definition
        fields = blueprint.fields.add_values(term.snapshot)
        base = "/cp/taxonomies/#{@taxonomy.handle}/terms"
        member = term.persisted? ? "#{base}/#{term.id}" : nil
        {
          title: term.title.presence || (term.persisted? ? "Untitled" : "New #{@taxonomy['title'].to_s.singularize.downcase}"),
          breadcrumbs: [ { label: @taxonomy["title"], url: cp_taxonomy_root_path(@taxonomy.handle) } ],
          resource_key: "term",
          blueprint: blueprint.to_publish_h,
          values: fields.pre_process.values.merge("slug" => term.slug, "lock_version" => term.lock_version),
          field_meta: fields.meta,
          meta: { id: term.id, status: "published", live: term.live?, lock_version: term.lock_version,
                  permalink: term.uri && "#{Nibble.config.url}#{term.uri}", updated_at: term.updated_at&.utc&.iso8601,
                  updated_by: nil, workflow: "simple", workflow_status: nil },
          draft: nil,
          can: { edit: Nibble::Access.can?(Nibble::Current.user, ability("edit"), term),
                 publish: false, delete: Nibble::Access.can?(Nibble::Current.user, ability("delete"), term), review: false },
          urls: { update: member || base, publish: nil, unpublish: nil, submit: nil, approve: nil, reject: nil,
                  discard: nil, trash: member && "#{member}/trash", preview: nil, versions: nil,
                  listing: "/cp/taxonomies/#{@taxonomy.handle}", create_another: "#{base}/new" }
        }
      end
    end
  end
end
