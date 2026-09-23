module Admin
  class PasskeysController < BaseController
    before_action :require_elevated_session

    def options
      user = Current.user
      options = WebAuthn::Credential.options_for_create(
        user: { id: user.id.to_s, name: user.email_address, display_name: user.name },
        exclude: user.user_credentials.pluck(:external_id),
        authenticator_selection: { resident_key: "preferred", user_verification: "required" }
      )
      session[:webauthn_challenge] = options.challenge
      render json: options
    end

    def create
      credential = WebAuthn::Credential.from_create(credential_params(:attestationObject))
      credential.verify(session.delete(:webauthn_challenge), user_verification: true)

      Current.user.user_credentials.create!(external_id: credential.id, public_key: credential.public_key,
        sign_count: credential.sign_count, name: params[:name].presence || "Passkey")
      Nibble::AuthLog.record("passkey_added", user: Current.user, ip: request.remote_ip)
      offer_recovery_codes
      head :created
    rescue WebAuthn::Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def update
      passkey.update!(name: params.require(:name))
      redirect_to edit_admin_account_path, notice: "Passkey renamed."
    end

    def destroy
      if last_factor?
        return redirect_to edit_admin_account_path,
          alert: "Your role asks for two-factor authentication, so set up another way in before removing this one."
      end

      passkey.destroy!
      Nibble::AuthLog.record("passkey_removed", user: Current.user, ip: request.remote_ip)
      redirect_to edit_admin_account_path, notice: "Passkey removed."
    end

    private

    def passkey = Current.user.user_credentials.find(params[:id])

    def last_factor?
      Current.user.requires_two_factor? && !Current.user.totp? && Current.user.user_credentials.count == 1
    end

    # Every second factor needs a way back in, not just the authenticator app.
    def offer_recovery_codes
      return if Current.user.recovery_codes.any?

      session[:recovery_codes] = Current.user.generate_recovery_codes!
    end

    def credential_params(*response_keys)
      params.require(:credential).permit(:id, :rawId, :type, response: [ :clientDataJSON, *response_keys ]).to_h
    end
  end
end
