# Nibble sign-in (Rails 8 authentication), rendered in the Control Plane.
module Nibble
  module Cp
    class SessionsController < Nibble::ApplicationController
      layout "nibble/cp"
      PENDING_WINDOW = 10.minutes
      CODE_ATTEMPTS = 5

      allow_unauthenticated_access only: %i[ new create challenge verify_challenge passkey_options passkey ]
      before_action :require_elevated_password, only: :elevate
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_cp_session_path, alert: "Try again later." }

      def new
        render inertia: "cp/auth/Login", props: { flash: flash.to_hash.slice("notice", "alert") }
      end

      def create
        email = params[:email_address].to_s
        return refuse_locked if Nibble::Lockout.locked?(email)

        user = Nibble::User.authenticate_by(params.permit(:email_address, :password))
        return refuse_password(email) unless user

        # The count only clears once they're actually in: a right password is half the sign-in when 2FA is on.
        return start_challenge(user) if user.two_factor?

        Nibble::Lockout.clear(email)
        start_new_session_for user
        redirect_to after_authentication_url
      end

      def elevate
        Nibble::Lockout.clear(Nibble::Current.user.email_address)
        elevate_session!
        Nibble::AuthLog.record("elevated", user: Nibble::Current.user, ip: request.remote_ip)
        head :ok
      end

      def challenge
        return redirect_to new_cp_session_path unless pending_user

        render inertia: "cp/auth/Challenge", props: { flash: flash.to_hash.slice("notice", "alert") }
      end

      def verify_challenge
        user = pending_user or return redirect_to(new_cp_session_path, alert: "Sign in again.")
        return refuse_locked if Nibble::Lockout.locked?(user.email_address)
        return refuse_code(user) unless accepted_code?(user)

        Nibble::Lockout.clear(user.email_address)
        clear_challenge
        start_new_session_for user
        redirect_to after_authentication_url
      end

      def passkey_options
        options = WebAuthn::Credential.options_for_get(user_verification: "required")
        session[:webauthn_challenge] = options.challenge
        render json: options
      end

      def passkey
        credential = WebAuthn::Credential.from_get(assertion_params)
        stored = Nibble::UserCredential.find_by(external_id: credential.id) or return head(:unauthorized)
        credential.verify(session.delete(:webauthn_challenge), public_key: stored.public_key, sign_count: stored.sign_count,
          user_verification: true)

        stored.update!(sign_count: credential.sign_count, last_used_at: Time.current)
        clear_challenge
        start_new_session_for stored.user
        render json: { redirect: after_authentication_url }
      rescue WebAuthn::Error => e
        render json: { error: e.message }, status: :unauthorized
      end

      def destroy
        Nibble::AuthLog.record("signed_out", user: Nibble::Current.user, ip: request.remote_ip)
        terminate_session
        redirect_to new_cp_session_path, status: :see_other
      end

      private

      def assertion_params
        params.require(:credential)
          .permit(:id, :rawId, :type, response: %i[clientDataJSON authenticatorData signature userHandle]).to_h
      end

      def require_elevated_password
        email = Nibble::Current.user&.email_address
        if Nibble::Lockout.locked?(email)
          return render json: { error: "Too many attempts. Try again later." }, status: :too_many_requests
        end
        return if Nibble::Current.user&.authenticate(params[:password].to_s)

        Nibble::Lockout.record_failure(email, ip: request.remote_ip)
        Nibble::AuthLog.record("elevation_refused", user: Nibble::Current.user, ip: request.remote_ip)
        render json: { error: "That password isn't right." }, status: :unauthorized
      end

      def refuse_locked
        redirect_to new_cp_session_path, alert: "Too many attempts. Try again in #{Nibble::Lockout::WINDOW.inspect}."
      end

      def refuse_password(email)
        count = Nibble::Lockout.record_failure(email, ip: request.remote_ip)
        Nibble::AuthLog.record(count >= Nibble::Lockout::ATTEMPTS ? "locked_out" : "sign_in_failed",
          user: Nibble::User.find_by(email_address: email.strip.downcase), ip: request.remote_ip, attempts: count)
        redirect_to new_cp_session_path, alert: "Try another email address or password."
      end

      def start_challenge(user)
        session[:pending_user_id] = user.id
        session[:pending_at] = Time.current.to_i
        session[:pending_attempts] = 0
        redirect_to challenge_cp_session_path
      end

      def pending_user
        return clear_challenge unless session[:pending_at].to_i > PENDING_WINDOW.ago.to_i

        Nibble::User.find_by(id: session[:pending_user_id])
      end

      def clear_challenge
        session.delete(:pending_user_id)
        session.delete(:pending_at)
        session.delete(:pending_attempts)
        nil
      end

      def accepted_code?(user)
        code = params[:code].to_s
        user.verify_totp(code) || user.consume_recovery_code(code)
      end

      # Counted per account, so starting the sign-in over doesn't buy five more guesses.
      def refuse_code(user)
        count = Nibble::Lockout.record_failure(user.email_address, kind: "code", ip: request.remote_ip)
        session[:pending_attempts] = session[:pending_attempts].to_i + 1
        if count >= Nibble::Lockout::CODE_ATTEMPTS
          Nibble::AuthLog.record("locked_out", user:, ip: request.remote_ip, attempts: count)
          clear_challenge
          return refuse_locked
        end
        if session[:pending_attempts] >= CODE_ATTEMPTS
          clear_challenge
          return redirect_to new_cp_session_path, alert: "Too many codes. Sign in again."
        end

        redirect_to challenge_cp_session_path, alert: "That code isn't right."
      end
    end
  end
end
