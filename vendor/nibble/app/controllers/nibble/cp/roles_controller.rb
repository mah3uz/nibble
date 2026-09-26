module Nibble
  module Cp
    class RolesController < BaseController
      before_action { authorize!("roles.manage") }
      before_action :require_elevated_session, only: %i[create update destroy]
      before_action :require_elevated_page, only: %i[index new edit]
      before_action :find_role, only: %i[edit update destroy]

      def index
        render inertia: "cp/roles/Index", props: { roles: Role.order(:title).map { |role| row(role) } }
      end

      def new
        render inertia: "cp/roles/Edit", props: form_props(Role.new)
      end

      def create
        return refuse_ungrantable("/cp/roles/new") if ungrantable.any?

        role = Role.new(role_attributes)
        return redirect_to("/cp/roles", notice: "Role created.") if role.save

        redirect_to "/cp/roles/new", inertia: { errors: messages(role) }
      end

      def edit
        render inertia: "cp/roles/Edit", props: form_props(@role)
      end

      def update
        return refuse_ungrantable("/cp/roles/#{@role.id}/edit") if ungrantable.any?
        return redirect_to("/cp/roles", notice: "Role updated.") if @role.update(role_attributes(@role))

        redirect_to "/cp/roles/#{@role.id}/edit", inertia: { errors: messages(@role) }
      end

      def destroy
        return redirect_to("/cp/roles", notice: "Role deleted.") if @role.destroy

        redirect_to "/cp/roles", alert: @role.errors.full_messages.to_sentence
      end

      private

      def find_role = @role = Role.find(params[:id])

      def form_props(role)
        { role: { id: role.id, title: role.title, handle: role.handle, superuser: role.superuser?,
                  require_2fa: role.require_2fa?, abilities: role.abilities, users: role.id ? role.users.count : 0 },
          groups: Nibble::Access::Catalogue.groups,
          can_assign_superuser: Nibble::Current.user.admin? }
      end

      def row(role)
        { id: role.id, title: role.title, handle: role.handle, superuser: role.superuser?,
          abilities: role.abilities.size, users: role.users.count, edit_url: "/cp/roles/#{role.id}/edit" }
      end

      def role_attributes(role = nil)
        attrs = params.require(:role).permit(:title, :handle, :superuser, :require_2fa, abilities: [])
        superuser = (ActiveModel::Type::Boolean.new.cast(attrs[:superuser]) || false) && Nibble::Current.user.admin?
        abilities = superuser ? [] : grantable(attrs[:abilities]) + unchecked(role)
        attrs.to_h.symbolize_keys.merge(superuser:, abilities:)
      end

      # Only what the catalogue offers can be ticked, so no request can invent an ability the editor never showed.
      def grantable(submitted) = Array(submitted) & Nibble::Access::Catalogue.abilities

      def ungrantable = Array(params.dig(:role, :abilities)) - Nibble::Access::Catalogue.abilities

      def refuse_ungrantable(path)
        redirect_to path, inertia: { errors: { abilities: "can't include #{ungrantable.to_sentence}" } }
      end

      # Abilities for schema a site no longer has are kept: they come back when the collection does.
      def unchecked(role) = role ? Nibble::Access::Catalogue.unknown(role.abilities) : []

      def messages(role) = role.errors.to_hash(true).transform_values { |list| list.join(", ") }
    end
  end
end
