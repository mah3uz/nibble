module Admin
  class TwoFactorController < BaseController
    before_action :require_elevated_session

    def create
      Current.user.start_totp_setup!
      flash[:two_factor_setup] = true
      redirect_to edit_admin_account_path
    end

    def confirm
      unless Current.user.confirm_totp(params[:code])
        flash[:two_factor_setup] = true
        return redirect_to edit_admin_account_path, inertia: { errors: { code: "isn't right. Try the current code." } }
      end

      session[:recovery_codes] = Current.user.generate_recovery_codes!
      Nibble::AuthLog.record("two_factor_enabled", user: Current.user, ip: request.remote_ip)
      redirect_to edit_admin_account_path, notice: "Two-factor authentication is on."
    end

    def acknowledge_recovery_codes
      session.delete(:recovery_codes)
      head :no_content
    end

    def recovery_codes
      return redirect_to(edit_admin_account_path, inertia: { errors: password_error }) unless password_ok?

      session[:recovery_codes] = Current.user.generate_recovery_codes!
      redirect_to edit_admin_account_path, notice: "New recovery codes generated. The old ones no longer work."
    end

    def destroy
      return redirect_to(edit_admin_account_path, inertia: { errors: password_error }) unless password_ok?
      if Current.user.requires_two_factor? && Current.user.user_credentials.none?
        return redirect_to edit_admin_account_path, alert: "Your role requires two-factor authentication."
      end

      Current.user.disable_two_factor!
      Nibble::AuthLog.record("two_factor_disabled", user: Current.user, ip: request.remote_ip)
      notice = if Current.user.passkeys?
        "The authenticator app is off. Your passkeys still sign you in."
      else
        "Two-factor authentication is off."
      end
      redirect_to edit_admin_account_path, notice:
    end

    private

    def password_ok? = Current.user.authenticate(params[:current_password].to_s)

    def password_error = { current_password: "is incorrect" }
  end
end
