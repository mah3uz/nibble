module Nibble
  module Cp
    class AccountsController < BaseController
      before_action :require_elevated_page, only: :edit

      def edit
        render inertia: "cp/account/Edit", props: { two_factor: two_factor_props, passkeys: passkey_props }
      end

      def update
        attrs = params.require(:user)
        attrs.key?(:current_password) ? update_password(attrs) : update_name(attrs)
      end

      private

      def update_name(attrs)
        if Nibble::Current.user.update(attrs.permit(:name))
          redirect_to edit_cp_account_path, notice: "Account updated."
        else
          redirect_to edit_cp_account_path, inertia: { errors: messages(Nibble::Current.user) }
        end
      end

      def update_password(attrs)
        unless Nibble::Current.user.authenticate(attrs[:current_password])
          return redirect_to edit_cp_account_path, inertia: { errors: { current_password: "is incorrect" } }
        end

        if Nibble::Current.user.update(attrs.permit(:password, :password_confirmation))
          Nibble::Current.user.sessions.where.not(id: Nibble::Current.session.id).destroy_all
          redirect_to edit_cp_account_path, notice: "Password changed. Your other sessions were signed out."
        else
          redirect_to edit_cp_account_path, inertia: { errors: messages(Nibble::Current.user) }
        end
      end

      def messages(user) = user.errors.to_hash(true).transform_values { |m| m.join(", ") }

      def two_factor_props
        user = Nibble::Current.user
        { enabled: user.totp?, required: user.requires_two_factor?,
          pending: (flash[:two_factor_setup] && !user.totp? && user.totp_secret) ? pending_setup(user) : nil,
          recovery_codes_left: user.recovery_codes.size, recovery_codes: session[:recovery_codes] }
      end

      def passkey_props
        Nibble::Current.user.user_credentials.order(:created_at).map do |credential|
          { id: credential.id, name: credential.name, created_at: credential.created_at.utc.iso8601,
            last_used_at: credential.last_used_at&.utc&.iso8601 }
        end
      end

      def pending_setup(user)
        uri = user.totp_provisioning_uri
        { secret: user.totp_secret, uri:, qr: RQRCode::QRCode.new(uri).as_svg(viewbox: true, use_path: true, module_size: 4) }
      end
    end
  end
end
