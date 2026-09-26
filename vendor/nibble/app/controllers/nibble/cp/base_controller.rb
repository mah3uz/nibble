module Nibble
  module Cp
    class NotAuthorized < StandardError; end

    class BaseController < Nibble::ApplicationController
      inertia_config(layout: "nibble/cp")
      rescue_from NotAuthorized, with: :deny_access
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      before_action { Nibble::Current.ip = request.remote_ip }
      before_action :require_two_factor_enrolment

      inertia_share cp: -> {
        {
          user: Nibble::Current.user&.slice(:id, :name, :email_address)&.merge(role: Nibble::Current.user.roles.map(&:title).to_sentence.presence),
          abilities: Nibble::Access.abilities(Nibble::Current.user),
          collections: Nibble.schema.collections.map { |item| collection_share(item) },
          nav: Nibble::Cp::Navigation.for(Nibble::Current.user),
          preferences: Nibble::UserPreferences.all(Nibble::Current.user),
          locales: Nibble.config.locales.map { |locale| { code: locale.code, default: locale.default } },
          site_url: Nibble.config.url,
          session: { lifetime: Nibble.config.session_idle.to_i, remaining: Nibble::Current.session&.remaining },
          flash: flash.to_hash.slice("notice", "alert")
        }
      }

      private

      def require_two_factor_enrolment
        return unless Nibble::Current.user&.requires_two_factor? && !Nibble::Current.user.two_factor?
        return if request.path.start_with?("/cp/account")

        redirect_to edit_cp_account_path, alert: "Your role asks for two-factor authentication. Set it up to carry on."
      end

      def collection_share(item)
        create = Nibble::Access.can?(Nibble::Current.user, "entries.#{item.handle}.create")
        { handle: item.handle, title: item["title"],
          create: create ? { label: "New #{item['title'].to_s.singularize.downcase}", url: "/cp/collections/#{item.handle}/entries/new" } : nil }
      end

      def authorize!(ability, record = nil)
        raise NotAuthorized unless Nibble::Access.can?(Nibble::Current.user, ability, record)
      end

      def deny_access
        request.format.json? ? head(:forbidden) : render(inertia: "cp/errors/Forbidden", status: :forbidden)
      end

      def render_not_found
        request.format.json? ? head(:not_found) : render(inertia: "cp/errors/NotFound", status: :not_found)
      end
    end
  end
end
