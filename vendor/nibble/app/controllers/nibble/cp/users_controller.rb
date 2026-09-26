module Nibble
  module Cp
    class UsersController < BaseController
      before_action { authorize!("users.manage") }
      before_action :require_elevated_session, only: %i[create update destroy send_reset revoke_session]
      before_action :require_elevated_page, only: %i[index edit]
      before_action :find_user, only: %i[edit update destroy send_reset revoke_session]
      before_action :only_a_superuser_touches_one, only: %i[edit update destroy send_reset revoke_session]

      def index
        render inertia: "cp/users/Index", props: {
          listing: Nibble::Cp::UserListing.new(user: Nibble::Current.user, params:).props,
          roles: role_options
        }
      end

      def create
        user = Nibble::User.new(invite_attributes)
        user.password = Nibble::User.generate_password
        unless user.save
          return redirect_to "/cp/users", inertia: { errors: messages(user) }
        end

        Nibble::PasswordsMailer.invite(user).deliver_later
        redirect_to "/cp/users", notice: "Invitation sent to #{user.email_address}."
      end

      def edit
        render inertia: "cp/users/Edit", props: {
          user: user_props(@user), roles: role_options, self: @user.id == Nibble::Current.user.id,
          sessions: @user.sessions.order(created_at: :desc).map { |session| session_props(session) }
        }
      end

      def update
        before = @user.roles.map(&:handle).sort
        if @user.update(user_attributes)
          record_role_change(before)
          return redirect_to("/cp/users", notice: "User updated.")
        end

        redirect_to "/cp/users/#{@user.id}/edit", inertia: { errors: messages(@user) }
      end

      def destroy
        raise NotAuthorized if @user.id == Nibble::Current.user.id
        return redirect_to("/cp/users", notice: "User deleted.") if @user.destroy

        redirect_to "/cp/users/#{@user.id}/edit", alert: @user.errors.full_messages.to_sentence
      end

      def send_reset
        Nibble::PasswordsMailer.reset(@user).deliver_later
        redirect_to "/cp/users/#{@user.id}/edit", notice: "Password reset sent to #{@user.email_address}."
      end

      def revoke_session
        @user.sessions.find(params[:session_id]).destroy!
        redirect_to "/cp/users/#{@user.id}/edit", notice: "Session revoked."
      end

      private

      def find_user = @user = Nibble::User.find(params[:id])

      def record_role_change(before)
        after = @user.reload.roles.map(&:handle).sort
        return if before == after

        Nibble::AuthLog.record("roles_changed", user: @user, ip: request.remote_ip, by: Nibble::Current.user.id, from: before, to: after)
      end

      def invite_attributes = params.require(:user).permit(:name, :email_address).merge(roles: submitted_roles)

      def user_attributes
        attrs = params.require(:user).permit(:name, :email_address)
        # Nobody edits their own roles: it's the one change that can't be undone from the same account.
        @user.id == Nibble::Current.user.id ? attrs : attrs.merge(roles: submitted_roles)
      end

      def submitted_roles
        roles = Nibble::Role.where(id: Array(params[:user][:role_ids])).to_a
        raise NotAuthorized if roles.any?(&:superuser?) && !Nibble::Current.user.admin?

        roles
      end

      # Full access is only ever handed on by someone who already has it.
      def only_a_superuser_touches_one
        raise NotAuthorized if @user.admin? && !Nibble::Current.user.admin?
      end

      def role_options = Nibble::Role.order(:title).map { |role| { id: role.id, title: role.title, superuser: role.superuser? } }

      def user_props(user)
        { id: user.id, name: user.name, email_address: user.email_address, role_ids: user.roles.map(&:id),
          last_login_at: user.last_login_at&.utc&.iso8601 }
      end

      def session_props(session)
        { id: session.id, user_agent: session.user_agent, ip_address: session.ip_address,
          created_at: session.created_at.utc.iso8601, current: session.id == Nibble::Current.session.id }
      end

      def messages(user) = user.errors.to_hash(true).transform_values { |list| list.join(", ") }
    end
  end
end
