module Authentication
  extend ActiveSupport::Concern

  ELEVATION_WINDOW = 15.minutes

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || start_page_url
    end

    def start_page_url
      handle = UserPreferences.get(Current.user, "start_page")
      handle == "dashboard" ? admin_root_url : admin_collection_root_url(handle)
    end

    def elevated? = Current.session&.elevated_at.present? && Current.session.elevated_at > ELEVATION_WINDOW.ago

    def elevate_session! = Current.session&.update!(elevated_at: Time.current)

    def elevated_until = Current.session&.elevated_at&.+(ELEVATION_WINDOW)

    def require_elevated_session
      return if elevated?
      return render(json: { error: "Confirm your password to carry on." }, status: :forbidden) if request.format.json? && !request.inertia?

      redirect_back_or_to admin_root_path
    end

    def require_elevated_page
      render inertia: "admin/Confirm" unless elevated?
    end

    def start_new_session_for(user)
      user.update_column(:last_login_at, Time.current)
      Nibble::AuthLog.record("signed_in", user:, ip: request.remote_ip)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
